# sentiment_amm

Anchor program for a perpetual two-sided sentiment market where
`price(BELIEVE) + price(DOUBT) == 1 USDC` at all times.

## Model
- Constant-product curve over two outcome reserves (`b`, `d`).
- `P_believe = d / (b + d)`, `P_doubt = b / (b + d)` — sum to 1 by construction.
- 1 USDC is always redeemable for `1 BELIEVE + 1 DOUBT` and vice versa; this
  anchors the prices to sum to $1.
- Buys: split USDC into a pair, add both to the pool, swap unwanted side
  along `b*d = k` for more of the wanted side.
- Sells: swap a portion of the outcome tokens into the opposite side so the
  user ends up with a balanced pair, then merge the pair back into USDC.
- LP tokens earn the 0.30% swap fee (adjust `SWAP_FEE_BPS`).
- The market is **perpetual** — it never resolves.

## Instructions
| ix | purpose |
|----|---------|
| `initialize_market(subject)` | Create mints, vault, and market PDA for a subject |
| `seed_liquidity(amount)` | First deposit: sets 50/50 price |
| `add_liquidity(usdc, min_lp)` | Proportional LP in |
| `remove_liquidity(lp, min_usdc)` | Proportional LP out |
| `buy_believe / buy_doubt(usdc_in, min_out)` | USDC → outcome token |
| `sell_believe / sell_doubt(tok_in, min_usdc)` | outcome token → USDC |

## Build
```
anchor build
anchor deploy --provider.cluster devnet
```

## Hooking up the iOS app
The Swift client signs transactions with the in-app Solana wallet and
invokes these instructions via a Jupiter-free direct call. The UI reads
`(believe_reserve, doubt_reserve)` from the market account to display live
prices — the WebSocket account subscription gives sub-second updates for
the charts.
