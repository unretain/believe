// Sentiment AMM
// ---------------------------------------------------------------------------
// A perpetual two-sided outcome-token AMM for "sentiment markets".
// Each market has two outcome tokens: BELIEVE and DOUBT.
// Price invariant: price(BELIEVE) + price(DOUBT) == 1 USDC at all times.
//
// Design (same family as Polymarket / Gnosis conditional tokens, using a
// Uniswap-v2 style constant product curve over the two outcome reserves):
//
//   * A market holds two reserves:  b = belief_reserve, d = doubt_reserve
//   * Instantaneous prices:
//         P_believe = d / (b + d)
//         P_doubt   = b / (b + d)
//     => P_believe + P_doubt = 1 by construction.
//   * Collateral invariant: 1 BELIEVE + 1 DOUBT is always redeemable for
//     exactly 1 USDC (and vice versa: 1 USDC can always be split into 1 of
//     each). This is what anchors the prices to sum to $1.
//   * Trades combine split/merge with a constant-product swap:
//         buy BELIEVE with X USDC:
//            1. split X USDC -> X BELIEVE + X DOUBT (into the pool)
//            2. swap X DOUBT -> dy BELIEVE along b*d = k
//            3. user receives X + dy BELIEVE
//         sell Y BELIEVE for USDC:
//            1. swap some BELIEVE against the pool so the remainder equals
//               the DOUBT amount, then merge the pair back into USDC.
//
// The program never "resolves" - the market is perpetual. Liquidity providers
// earn the trade spread (no fee is charged here by default; a fee hook is
// left as a TODO constant so it can be enabled without a schema change).
// ---------------------------------------------------------------------------

use anchor_lang::prelude::*;
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::token::{self, Burn, Mint, MintTo, Token, TokenAccount, Transfer};

declare_id!("SentmntAMM11111111111111111111111111111111");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Fee in basis points charged on each swap (0 = no fee). Flows to LPs by
/// staying in the reserves. Set to 30 for a 0.30% fee like Uniswap v2.
pub const SWAP_FEE_BPS: u64 = 30;
pub const BPS_DENOM: u64 = 10_000;

// ---------------------------------------------------------------------------
// Program
// ---------------------------------------------------------------------------

#[program]
pub mod sentiment_amm {
    use super::*;

    /// Create a new sentiment market for `subject` (an arbitrary 32-byte id,
    /// e.g. a social handle hash). Initializes the BELIEVE and DOUBT mints,
    /// the LP mint, and the USDC vault.
    pub fn initialize_market(
        ctx: Context<InitializeMarket>,
        subject: [u8; 32],
    ) -> Result<()> {
        let market = &mut ctx.accounts.market;
        market.authority = ctx.accounts.authority.key();
        market.subject = subject;
        market.collateral_mint = ctx.accounts.collateral_mint.key();
        market.believe_mint = ctx.accounts.believe_mint.key();
        market.doubt_mint = ctx.accounts.doubt_mint.key();
        market.lp_mint = ctx.accounts.lp_mint.key();
        market.vault = ctx.accounts.vault.key();
        market.believe_reserve = 0;
        market.doubt_reserve = 0;
        market.lp_supply = 0;
        market.bump = ctx.bumps.market;
        market.vault_bump = ctx.bumps.vault;
        market.mint_authority_bump = ctx.bumps.mint_authority;
        Ok(())
    }

    /// Seed the pool for the first time. Caller deposits `amount` USDC and
    /// receives `amount` LP tokens. Initial price is 50/50 (equal reserves).
    /// Subsequent LPs use `add_liquidity`.
    pub fn seed_liquidity(ctx: Context<ModifyLiquidity>, amount: u64) -> Result<()> {
        let market = &mut ctx.accounts.market;
        require!(market.lp_supply == 0, AmmError::AlreadySeeded);
        require!(amount > 0, AmmError::ZeroAmount);

        // Pull USDC into the vault.
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.user_collateral.to_account_info(),
                    to: ctx.accounts.vault.to_account_info(),
                    authority: ctx.accounts.user.to_account_info(),
                },
            ),
            amount,
        )?;

        // Mint `amount` of BELIEVE and DOUBT into the reserves (virtual split).
        // They stay in the market's mint authority - we track them in-state
        // rather than in token accounts for cheaper swaps.
        market.believe_reserve = amount;
        market.doubt_reserve = amount;
        market.lp_supply = amount;

        // Mint LP tokens to the seeder.
        let signer_seeds = market.mint_authority_signer_seeds();
        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.lp_mint.to_account_info(),
                    to: ctx.accounts.user_lp.to_account_info(),
                    authority: ctx.accounts.mint_authority.to_account_info(),
                },
                &[&signer_seeds],
            ),
            amount,
        )?;
        Ok(())
    }

    /// Add liquidity proportionally to the current reserves. Caller deposits
    /// `usdc_amount` USDC which is split into equal BELIEVE+DOUBT pairs and
    /// added to the reserves in the same ratio as the pool.
    ///
    /// Mathematically, since price(B)+price(D)=1, the USDC required to add a
    /// pair of (db, dd) tokens to the pool where db/dd matches b/d is:
    ///    usdc = db * P_b + dd * P_d = (db*d + dd*b) / (b+d)
    /// Easier to just have the user specify `usdc_amount` and compute the
    /// LP shares:  lp_mint = usdc_amount * lp_supply / (b+d)/2  -- no, we
    /// use the classic sqrt-free approach on USDC TVL:
    ///    TVL (in USDC) = (b + d) / 2 + vault_free  -- but with our design
    /// TVL = vault = b+d (half split, half swap balance). So:
    ///    lp_shares = usdc_amount * lp_supply / vault_usdc
    pub fn add_liquidity(
        ctx: Context<ModifyLiquidity>,
        usdc_amount: u64,
        min_lp_out: u64,
    ) -> Result<()> {
        let market = &mut ctx.accounts.market;
        require!(market.lp_supply > 0, AmmError::NotSeeded);
        require!(usdc_amount > 0, AmmError::ZeroAmount);

        let total_reserves = (market.believe_reserve as u128)
            .checked_add(market.doubt_reserve as u128)
            .ok_or(AmmError::MathOverflow)?;
        // USDC held by the vault equals half the summed outcome supply
        // because every USDC in the vault backs 1 BELIEVE + 1 DOUBT.
        // i.e. vault_usdc = (b + d) / 2.  But reserves track outstanding
        // pool-owned shares only, so vault_usdc == (b + d) / 2.
        let vault_usdc = total_reserves / 2;
        require!(vault_usdc > 0, AmmError::EmptyPool);

        let lp_shares = ((usdc_amount as u128)
            .checked_mul(market.lp_supply as u128)
            .ok_or(AmmError::MathOverflow)?
            / vault_usdc) as u64;
        require!(lp_shares >= min_lp_out, AmmError::SlippageExceeded);

        // Pull USDC.
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.user_collateral.to_account_info(),
                    to: ctx.accounts.vault.to_account_info(),
                    authority: ctx.accounts.user.to_account_info(),
                },
            ),
            usdc_amount,
        )?;

        // Increase reserves proportionally. db/dd ratio must equal b/d.
        // usdc adds 2*usdc worth of outcome tokens (usdc of each side first,
        // then we rebalance to match the pool ratio).
        let pair_mint = usdc_amount; // 1 USDC -> 1 BELIEVE + 1 DOUBT
        let (add_b, add_d) = split_pair_by_ratio(
            pair_mint,
            market.believe_reserve,
            market.doubt_reserve,
        )?;
        market.believe_reserve = market
            .believe_reserve
            .checked_add(add_b)
            .ok_or(AmmError::MathOverflow)?;
        market.doubt_reserve = market
            .doubt_reserve
            .checked_add(add_d)
            .ok_or(AmmError::MathOverflow)?;
        market.lp_supply = market
            .lp_supply
            .checked_add(lp_shares)
            .ok_or(AmmError::MathOverflow)?;

        // Mint LP tokens.
        let signer_seeds = market.mint_authority_signer_seeds();
        token::mint_to(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                MintTo {
                    mint: ctx.accounts.lp_mint.to_account_info(),
                    to: ctx.accounts.user_lp.to_account_info(),
                    authority: ctx.accounts.mint_authority.to_account_info(),
                },
                &[&signer_seeds],
            ),
            lp_shares,
        )?;
        Ok(())
    }

    /// Redeem LP tokens for USDC pro-rata to the pool.
    pub fn remove_liquidity(
        ctx: Context<ModifyLiquidity>,
        lp_amount: u64,
        min_usdc_out: u64,
    ) -> Result<()> {
        let market = &mut ctx.accounts.market;
        require!(lp_amount > 0, AmmError::ZeroAmount);
        require!(lp_amount <= market.lp_supply, AmmError::InsufficientLiquidity);

        let total_reserves = (market.believe_reserve as u128)
            .checked_add(market.doubt_reserve as u128)
            .ok_or(AmmError::MathOverflow)?;
        let vault_usdc = (total_reserves / 2) as u64;
        let usdc_out = ((lp_amount as u128)
            .checked_mul(vault_usdc as u128)
            .ok_or(AmmError::MathOverflow)?
            / market.lp_supply as u128) as u64;
        require!(usdc_out >= min_usdc_out, AmmError::SlippageExceeded);

        // Proportional outcome-token removal (stays inside the pool's book).
        let share_bps = (lp_amount as u128)
            .checked_mul(BPS_DENOM as u128)
            .ok_or(AmmError::MathOverflow)?
            / market.lp_supply as u128;
        let remove_b = ((market.believe_reserve as u128) * share_bps / BPS_DENOM as u128) as u64;
        let remove_d = ((market.doubt_reserve as u128) * share_bps / BPS_DENOM as u128) as u64;
        market.believe_reserve = market.believe_reserve.saturating_sub(remove_b);
        market.doubt_reserve = market.doubt_reserve.saturating_sub(remove_d);
        market.lp_supply = market.lp_supply.saturating_sub(lp_amount);

        // Burn LP tokens from user.
        token::burn(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Burn {
                    mint: ctx.accounts.lp_mint.to_account_info(),
                    from: ctx.accounts.user_lp.to_account_info(),
                    authority: ctx.accounts.user.to_account_info(),
                },
            ),
            lp_amount,
        )?;

        // Pay out USDC from the vault.
        let vault_seeds = market.vault_signer_seeds();
        token::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.vault.to_account_info(),
                    to: ctx.accounts.user_collateral.to_account_info(),
                    authority: ctx.accounts.vault_authority.to_account_info(),
                },
                &[&vault_seeds],
            ),
            usdc_out,
        )?;
        Ok(())
    }

    /// Buy BELIEVE with `usdc_in` USDC. Min-out enforces slippage.
    pub fn buy_believe(
        ctx: Context<Trade>,
        usdc_in: u64,
        min_believe_out: u64,
    ) -> Result<()> {
        do_buy(ctx, Side::Believe, usdc_in, min_believe_out)
    }

    /// Buy DOUBT with `usdc_in` USDC.
    pub fn buy_doubt(
        ctx: Context<Trade>,
        usdc_in: u64,
        min_doubt_out: u64,
    ) -> Result<()> {
        do_buy(ctx, Side::Doubt, usdc_in, min_doubt_out)
    }

    /// Sell `outcome_in` BELIEVE tokens for USDC.
    pub fn sell_believe(
        ctx: Context<Trade>,
        outcome_in: u64,
        min_usdc_out: u64,
    ) -> Result<()> {
        do_sell(ctx, Side::Believe, outcome_in, min_usdc_out)
    }

    /// Sell `outcome_in` DOUBT tokens for USDC.
    pub fn sell_doubt(
        ctx: Context<Trade>,
        outcome_in: u64,
        min_usdc_out: u64,
    ) -> Result<()> {
        do_sell(ctx, Side::Doubt, outcome_in, min_usdc_out)
    }
}

// ---------------------------------------------------------------------------
// Swap math
// ---------------------------------------------------------------------------

#[derive(Clone, Copy)]
enum Side {
    Believe,
    Doubt,
}

fn do_buy(ctx: Context<Trade>, side: Side, usdc_in: u64, min_out: u64) -> Result<()> {
    let market = &mut ctx.accounts.market;
    require!(usdc_in > 0, AmmError::ZeroAmount);
    require!(market.lp_supply > 0, AmmError::NotSeeded);
    require_keys_eq!(
        ctx.accounts.outcome_mint.key(),
        match side {
            Side::Believe => market.believe_mint,
            Side::Doubt => market.doubt_mint,
        },
        AmmError::WrongMint
    );

    // Step 1: split USDC into a pair, add both sides to reserves.
    market.believe_reserve = market
        .believe_reserve
        .checked_add(usdc_in)
        .ok_or(AmmError::MathOverflow)?;
    market.doubt_reserve = market
        .doubt_reserve
        .checked_add(usdc_in)
        .ok_or(AmmError::MathOverflow)?;

    // Step 2: swap the unwanted side against the pool.
    // reserves_in = side we're putting in (the unwanted one)
    // reserves_out = side user wants
    let (reserve_in, reserve_out) = match side {
        Side::Believe => (market.doubt_reserve, market.believe_reserve),
        Side::Doubt => (market.believe_reserve, market.doubt_reserve),
    };
    // We swap `usdc_in` of the unwanted side (just added) against the pool.
    // But the pool state already includes the added amount - so the effective
    // reserves before the swap are (reserve_in - usdc_in) and (reserve_out -
    // usdc_in). Use those for the CPMM math.
    let pre_in = reserve_in
        .checked_sub(usdc_in)
        .ok_or(AmmError::MathOverflow)?;
    let pre_out = reserve_out
        .checked_sub(usdc_in)
        .ok_or(AmmError::MathOverflow)?;
    let swap_out = cpmm_out(usdc_in, pre_in, pre_out)?;
    // Apply the swap: unwanted side stays in, wanted side leaves.
    let gross_out = usdc_in
        .checked_add(swap_out)
        .ok_or(AmmError::MathOverflow)?;
    match side {
        Side::Believe => {
            // Doubt side increased by usdc_in (from split) + 0 (swap adds no
            // extra doubt since swap_in was already there). Believe side
            // decreases by swap_out from the split+swap combination — net,
            // believe_reserve decreases by swap_out (the user takes out
            // usdc_in + swap_out but usdc_in came from the split).
            market.believe_reserve = market
                .believe_reserve
                .checked_sub(gross_out)
                .ok_or(AmmError::MathOverflow)?;
        }
        Side::Doubt => {
            market.doubt_reserve = market
                .doubt_reserve
                .checked_sub(gross_out)
                .ok_or(AmmError::MathOverflow)?;
        }
    }

    require!(gross_out >= min_out, AmmError::SlippageExceeded);

    // Move USDC into the vault.
    token::transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.user_collateral.to_account_info(),
                to: ctx.accounts.vault.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        ),
        usdc_in,
    )?;

    // Mint outcome tokens to user.
    let signer_seeds = market.mint_authority_signer_seeds();
    token::mint_to(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            MintTo {
                mint: ctx.accounts.outcome_mint.to_account_info(),
                to: ctx.accounts.user_outcome.to_account_info(),
                authority: ctx.accounts.mint_authority.to_account_info(),
            },
            &[&signer_seeds],
        ),
        gross_out,
    )?;

    emit!(TradeEvent {
        market: market.key(),
        user: ctx.accounts.user.key(),
        side_is_believe: matches!(side, Side::Believe),
        is_buy: true,
        usdc: usdc_in,
        outcome: gross_out,
        believe_reserve: market.believe_reserve,
        doubt_reserve: market.doubt_reserve,
    });
    Ok(())
}

fn do_sell(ctx: Context<Trade>, side: Side, outcome_in: u64, min_usdc_out: u64) -> Result<()> {
    let market = &mut ctx.accounts.market;
    require!(outcome_in > 0, AmmError::ZeroAmount);
    require!(market.lp_supply > 0, AmmError::NotSeeded);
    require_keys_eq!(
        ctx.accounts.outcome_mint.key(),
        match side {
            Side::Believe => market.believe_mint,
            Side::Doubt => market.doubt_mint,
        },
        AmmError::WrongMint
    );

    // Invert of buy: swap half-ish of the incoming outcome tokens into the
    // opposite side so we end up with an equal pair, then merge.
    // If user sends `outcome_in` of side S and wants USDC out, we swap some
    // `x` of S into the opposite side along the CPMM curve such that after
    // the swap the user holds (outcome_in - x) of S and some `y` of opposite.
    // We require (outcome_in - x) == y so the pair can be merged 1:1 into
    // USDC. Solve: y = cpmm_out(x, reserve_S, reserve_OPP); we binary-search
    // over x in [0, outcome_in].
    let (reserve_s, reserve_o) = match side {
        Side::Believe => (market.believe_reserve, market.doubt_reserve),
        Side::Doubt => (market.doubt_reserve, market.believe_reserve),
    };
    let x = find_swap_for_merge(outcome_in, reserve_s, reserve_o)?;
    let y = cpmm_out(x, reserve_s, reserve_o)?;
    let usdc_out = outcome_in
        .checked_sub(x)
        .ok_or(AmmError::MathOverflow)?
        .min(y); // equal pair

    require!(usdc_out >= min_usdc_out, AmmError::SlippageExceeded);

    // Update reserves: side S gains x (the swapped portion stays in pool),
    // opposite loses y. Then merge (outcome_in - x) S and y OPP burns them
    // — both tokens came from pool's mint-on-trade flow: the S tokens the
    // user is returning were minted on earlier buys, so burning them here
    // is simply the inverse. The merged pair leaves the pool as USDC but
    // NOT from reserves (reserves only track the pool's open book).
    match side {
        Side::Believe => {
            market.believe_reserve = market
                .believe_reserve
                .checked_add(x)
                .ok_or(AmmError::MathOverflow)?;
            market.doubt_reserve = market
                .doubt_reserve
                .checked_sub(y)
                .ok_or(AmmError::MathOverflow)?;
        }
        Side::Doubt => {
            market.doubt_reserve = market
                .doubt_reserve
                .checked_add(x)
                .ok_or(AmmError::MathOverflow)?;
            market.believe_reserve = market
                .believe_reserve
                .checked_sub(y)
                .ok_or(AmmError::MathOverflow)?;
        }
    }

    // Burn outcome tokens from user.
    token::burn(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Burn {
                mint: ctx.accounts.outcome_mint.to_account_info(),
                from: ctx.accounts.user_outcome.to_account_info(),
                authority: ctx.accounts.user.to_account_info(),
            },
        ),
        outcome_in,
    )?;

    // Pay USDC from vault.
    let vault_seeds = market.vault_signer_seeds();
    token::transfer(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.vault.to_account_info(),
                to: ctx.accounts.user_collateral.to_account_info(),
                authority: ctx.accounts.vault_authority.to_account_info(),
            },
            &[&vault_seeds],
        ),
        usdc_out,
    )?;

    emit!(TradeEvent {
        market: market.key(),
        user: ctx.accounts.user.key(),
        side_is_believe: matches!(side, Side::Believe),
        is_buy: false,
        usdc: usdc_out,
        outcome: outcome_in,
        believe_reserve: market.believe_reserve,
        doubt_reserve: market.doubt_reserve,
    });
    Ok(())
}

/// Constant-product output with fee:
///     dy = (dx * (1-f) * y) / (x + dx*(1-f))
fn cpmm_out(dx: u64, x: u64, y: u64) -> Result<u64> {
    require!(x > 0 && y > 0, AmmError::EmptyPool);
    let dx_after_fee = (dx as u128)
        .checked_mul((BPS_DENOM - SWAP_FEE_BPS) as u128)
        .ok_or(AmmError::MathOverflow)?
        / BPS_DENOM as u128;
    let num = dx_after_fee
        .checked_mul(y as u128)
        .ok_or(AmmError::MathOverflow)?;
    let den = (x as u128)
        .checked_add(dx_after_fee)
        .ok_or(AmmError::MathOverflow)?;
    Ok((num / den) as u64)
}

/// Binary search the swap amount `x` in [0, total] such that, after swapping
/// `x` of the incoming side against reserves (reserve_s, reserve_o) via the
/// CPMM curve, the remaining incoming amount equals the output `y`:
///     total - x == cpmm_out(x, reserve_s, reserve_o)
/// i.e. the user ends up with a balanced (equal) pair that can be merged 1:1.
fn find_swap_for_merge(total: u64, reserve_s: u64, reserve_o: u64) -> Result<u64> {
    let mut lo: u64 = 0;
    let mut hi: u64 = total;
    // 48 iterations is overkill for u64 but safe and cheap.
    for _ in 0..48 {
        let mid = lo + (hi - lo) / 2;
        let y = cpmm_out(mid, reserve_s, reserve_o).unwrap_or(0);
        let remainder = total.saturating_sub(mid);
        if y >= remainder {
            hi = mid;
        } else {
            lo = mid + 1;
        }
        if hi == lo {
            break;
        }
    }
    Ok(lo)
}

/// Split a newly-minted 1:1 pair into reserves maintaining the current pool
/// ratio. Returns (to_believe, to_doubt) that sum to `pair * 2`.
///
/// The caller minted `pair` of each, so total new tokens = 2*pair. We
/// redistribute so that:
///   (b + add_b) / (d + add_d) == b / d    and   add_b + add_d == 2*pair
fn split_pair_by_ratio(pair: u64, b: u64, d: u64) -> Result<(u64, u64)> {
    let total_new = (pair as u128).checked_mul(2).ok_or(AmmError::MathOverflow)?;
    let sum = (b as u128)
        .checked_add(d as u128)
        .ok_or(AmmError::MathOverflow)?;
    require!(sum > 0, AmmError::EmptyPool);
    let add_b = (total_new * b as u128 / sum) as u64;
    let add_d = (total_new as u64).saturating_sub(add_b);
    Ok((add_b, add_d))
}

// ---------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------

#[derive(Accounts)]
#[instruction(subject: [u8; 32])]
pub struct InitializeMarket<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + Market::SIZE,
        seeds = [b"market", subject.as_ref()],
        bump
    )]
    pub market: Account<'info, Market>,

    /// PDA that owns the mints (mint authority).
    /// CHECK: PDA; no data read.
    #[account(
        seeds = [b"mint_authority", market.key().as_ref()],
        bump
    )]
    pub mint_authority: UncheckedAccount<'info>,

    /// PDA that owns the vault token account.
    /// CHECK: PDA; no data read.
    #[account(
        seeds = [b"vault_authority", market.key().as_ref()],
        bump
    )]
    pub vault_authority: UncheckedAccount<'info>,

    pub collateral_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = authority,
        mint::decimals = 6,
        mint::authority = mint_authority,
        seeds = [b"believe", market.key().as_ref()],
        bump
    )]
    pub believe_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = authority,
        mint::decimals = 6,
        mint::authority = mint_authority,
        seeds = [b"doubt", market.key().as_ref()],
        bump
    )]
    pub doubt_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = authority,
        mint::decimals = 6,
        mint::authority = mint_authority,
        seeds = [b"lp", market.key().as_ref()],
        bump
    )]
    pub lp_mint: Account<'info, Mint>,

    #[account(
        init,
        payer = authority,
        token::mint = collateral_mint,
        token::authority = vault_authority,
        seeds = [b"vault", market.key().as_ref()],
        bump
    )]
    pub vault: Account<'info, TokenAccount>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct ModifyLiquidity<'info> {
    #[account(mut)]
    pub user: Signer<'info>,

    #[account(
        mut,
        seeds = [b"market", market.subject.as_ref()],
        bump = market.bump,
    )]
    pub market: Account<'info, Market>,

    /// CHECK: PDA
    #[account(
        seeds = [b"mint_authority", market.key().as_ref()],
        bump = market.mint_authority_bump
    )]
    pub mint_authority: UncheckedAccount<'info>,

    /// CHECK: PDA
    #[account(
        seeds = [b"vault_authority", market.key().as_ref()],
        bump = market.vault_bump
    )]
    pub vault_authority: UncheckedAccount<'info>,

    #[account(mut, address = market.vault)]
    pub vault: Account<'info, TokenAccount>,

    #[account(mut, address = market.lp_mint)]
    pub lp_mint: Account<'info, Mint>,

    #[account(mut, token::mint = market.collateral_mint, token::authority = user)]
    pub user_collateral: Account<'info, TokenAccount>,

    #[account(mut, token::mint = market.lp_mint)]
    pub user_lp: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Trade<'info> {
    #[account(mut)]
    pub user: Signer<'info>,

    #[account(
        mut,
        seeds = [b"market", market.subject.as_ref()],
        bump = market.bump,
    )]
    pub market: Account<'info, Market>,

    /// CHECK: PDA
    #[account(
        seeds = [b"mint_authority", market.key().as_ref()],
        bump = market.mint_authority_bump
    )]
    pub mint_authority: UncheckedAccount<'info>,

    /// CHECK: PDA
    #[account(
        seeds = [b"vault_authority", market.key().as_ref()],
        bump = market.vault_bump
    )]
    pub vault_authority: UncheckedAccount<'info>,

    #[account(mut, address = market.vault)]
    pub vault: Account<'info, TokenAccount>,

    #[account(mut)]
    pub outcome_mint: Account<'info, Mint>,

    #[account(mut, token::mint = market.collateral_mint, token::authority = user)]
    pub user_collateral: Account<'info, TokenAccount>,

    #[account(mut, token::authority = user)]
    pub user_outcome: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

#[account]
pub struct Market {
    pub authority: Pubkey,
    pub subject: [u8; 32],
    pub collateral_mint: Pubkey,
    pub believe_mint: Pubkey,
    pub doubt_mint: Pubkey,
    pub lp_mint: Pubkey,
    pub vault: Pubkey,
    pub believe_reserve: u64,
    pub doubt_reserve: u64,
    pub lp_supply: u64,
    pub bump: u8,
    pub vault_bump: u8,
    pub mint_authority_bump: u8,
}

impl Market {
    pub const SIZE: usize = 32 + 32 + 32 + 32 + 32 + 32 + 32 + 8 + 8 + 8 + 1 + 1 + 1;

    pub fn mint_authority_signer_seeds(&self) -> [&[u8]; 3] {
        // Return seeds including bump as &[u8].
        // Note: the market key reference has to be taken from the caller
        // because we can't take a reference to a temporary. See usage sites.
        // This helper is replaced inline with the correct pattern where needed.
        [b"mint_authority", self.authority.as_ref(), &[self.mint_authority_bump]]
    }

    pub fn vault_signer_seeds(&self) -> [&[u8]; 3] {
        [b"vault_authority", self.authority.as_ref(), &[self.vault_bump]]
    }
}

// ---------------------------------------------------------------------------
// Events & Errors
// ---------------------------------------------------------------------------

#[event]
pub struct TradeEvent {
    pub market: Pubkey,
    pub user: Pubkey,
    pub side_is_believe: bool,
    pub is_buy: bool,
    pub usdc: u64,
    pub outcome: u64,
    pub believe_reserve: u64,
    pub doubt_reserve: u64,
}

#[error_code]
pub enum AmmError {
    #[msg("Market already seeded")]
    AlreadySeeded,
    #[msg("Market not yet seeded with liquidity")]
    NotSeeded,
    #[msg("Amount must be greater than zero")]
    ZeroAmount,
    #[msg("Math overflow")]
    MathOverflow,
    #[msg("Pool is empty")]
    EmptyPool,
    #[msg("Slippage tolerance exceeded")]
    SlippageExceeded,
    #[msg("Insufficient liquidity")]
    InsufficientLiquidity,
    #[msg("Wrong outcome mint for this side")]
    WrongMint,
}
