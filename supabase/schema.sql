-- Run this in Supabase SQL Editor to set up shared liquidity.
-- Safe to re-run.

create extension if not exists "pgcrypto";

create table if not exists markets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  title text not null,
  handle text not null,
  x_handle text not null unique,
  image_url text not null default '',
  avatar_url text not null default '',
  category text not null,
  believe_pool double precision not null,
  doubt_pool double precision not null,
  volume_24h double precision not null default 0,
  total_volume double precision not null default 0,
  holders int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists price_history (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references markets(id) on delete cascade,
  ts timestamptz not null default now(),
  believe_price double precision not null,
  doubt_price double precision not null
);
create index if not exists price_history_market_ts on price_history(market_id, ts);

create table if not exists wallets (
  address text primary key,
  balance double precision not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists positions (
  id uuid primary key default gen_random_uuid(),
  wallet text not null,
  market_id uuid not null references markets(id) on delete cascade,
  side text not null check (side in ('Believe','Doubt')),
  shares double precision not null,
  avg_cost double precision not null,
  total_invested double precision not null,
  unique (wallet, market_id, side)
);

create table if not exists trades (
  id uuid primary key default gen_random_uuid(),
  wallet text not null,
  market_id uuid not null references markets(id) on delete cascade,
  side text not null check (side in ('Believe','Doubt')),
  is_buy boolean not null,
  amount double precision not null,
  shares double precision not null,
  price double precision not null,
  ts timestamptz not null default now()
);
create index if not exists trades_market_ts on trades(market_id, ts desc);

-- Allow anon (client) to read/write through PostgREST.
alter table markets enable row level security;
alter table price_history enable row level security;
alter table wallets enable row level security;
alter table positions enable row level security;
alter table trades enable row level security;

drop policy if exists "read markets" on markets;
create policy "read markets" on markets for select using (true);

drop policy if exists "read price_history" on price_history;
create policy "read price_history" on price_history for select using (true);

drop policy if exists "read trades" on trades;
create policy "read trades" on trades for select using (true);

drop policy if exists "read wallets" on wallets;
create policy "read wallets" on wallets for select using (true);

drop policy if exists "read positions" on positions;
create policy "read positions" on positions for select using (true);

-- ----------------- SEED MARKETS -----------------
insert into markets (name, title, handle, x_handle, image_url, avatar_url, category, believe_pool, doubt_pool, volume_24h, total_volume, holders)
values
  ('Ben Pasternak','Entrepreneur','@bfrfrfrfr','@bfrfrfrfr','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/g7d124v0loog19flgnndi.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/g7d124v0loog19flgnndi.png','Tech',389,611,0,0,0),
  ('Elon Musk','CEO, Tesla & SpaceX','@elonmusk','@elonmusk','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/jk7sz6p9e8pozpiudiipj.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/jk7sz6p9e8pozpiudiipj.png','Tech',430,570,0,0,0),
  ('Taylor Swift','Artist & Songwriter','@taylorswift','@taylorswift13','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/ov3iy2irr6511okrda3uj.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/ov3iy2irr6511okrda3uj.png','Entertainment',470,530,0,0,0),
  ('MrBeast','YouTuber & Philanthropist','@mrbeast','@MrBeast','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/y1eg93i4ejp56w7x6eyhm.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/y1eg93i4ejp56w7x6eyhm.png','Creators',310,690,0,0,0),
  ('LeBron James','NBA Player','@kingjames','@KingJames','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/d8h5vnqfaf6mxpa6e3sn6.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/d8h5vnqfaf6mxpa6e3sn6.png','Sports',480,520,0,0,0),
  ('Vitalik Buterin','Ethereum Co-Founder','@vitalik','@VitalikButerin','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/4u8tjahknefpfkqqnnolh.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/4u8tjahknefpfkqqnnolh.png','Crypto',410,590,0,0,0),
  ('Alexandria O-C','U.S. Representative','@aoc','@AOC','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/8p8nyb5cjoiyedm531mq9.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/8p8nyb5cjoiyedm531mq9.png','Politics',580,420,0,0,0),
  ('Charli D''Amelio','Content Creator','@charlidamelio','@charlidamelio','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/snv3l7esbs1t35nist6ao.png','https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/snv3l7esbs1t35nist6ao.png','Creators',440,560,0,0,0),
  -- Crypto
  ('Bitcoin','BTC · Digital Gold','$BTC','$BTC_coin','https://assets.coingecko.com/coins/images/1/large/bitcoin.png','https://assets.coingecko.com/coins/images/1/large/bitcoin.png','Crypto',350,650,0,0,0),
  ('Ethereum','ETH · Smart Contracts','$ETH','$ETH_coin','https://assets.coingecko.com/coins/images/279/large/ethereum.png','https://assets.coingecko.com/coins/images/279/large/ethereum.png','Crypto',400,600,0,0,0),
  ('Solana','SOL · High-speed L1','$SOL','$SOL_coin','https://assets.coingecko.com/coins/images/4128/large/solana.png','https://assets.coingecko.com/coins/images/4128/large/solana.png','Crypto',330,670,0,0,0),
  ('Dogecoin','DOGE · The people''s coin','$DOGE','$DOGE_coin','https://assets.coingecko.com/coins/images/5/large/dogecoin.png','https://assets.coingecko.com/coins/images/5/large/dogecoin.png','Crypto',520,480,0,0,0),
  -- Sports teams
  ('LA Lakers','NBA · Los Angeles','@Lakers','@Lakers','https://a.espncdn.com/i/teamlogos/nba/500/lal.png','https://a.espncdn.com/i/teamlogos/nba/500/lal.png','Sports',460,540,0,0,0),
  ('Golden State Warriors','NBA · Bay Area','@warriors','@warriors','https://a.espncdn.com/i/teamlogos/nba/500/gs.png','https://a.espncdn.com/i/teamlogos/nba/500/gs.png','Sports',440,560,0,0,0),
  ('Dallas Cowboys','NFL · America''s Team','@dallascowboys','@dallascowboys','https://a.espncdn.com/i/teamlogos/nfl/500/dal.png','https://a.espncdn.com/i/teamlogos/nfl/500/dal.png','Sports',510,490,0,0,0),
  ('Kansas City Chiefs','NFL · Super Bowl reign','@Chiefs','@Chiefs','https://a.espncdn.com/i/teamlogos/nfl/500/kc.png','https://a.espncdn.com/i/teamlogos/nfl/500/kc.png','Sports',380,620,0,0,0),
  ('Real Madrid','La Liga · Los Blancos','@realmadrid','@realmadrid','https://a.espncdn.com/i/teamlogos/soccer/500/86.png','https://a.espncdn.com/i/teamlogos/soccer/500/86.png','Sports',350,650,0,0,0),
  ('Manchester City','EPL · The Citizens','@ManCity','@ManCity','https://a.espncdn.com/i/teamlogos/soccer/500/382.png','https://a.espncdn.com/i/teamlogos/soccer/500/382.png','Sports',400,600,0,0,0),
  ('New York Yankees','MLB · The Bronx Bombers','@Yankees','@Yankees','https://a.espncdn.com/i/teamlogos/mlb/500/nyy.png','https://a.espncdn.com/i/teamlogos/mlb/500/nyy.png','Sports',450,550,0,0,0),
  -- More Tech
  ('Sam Altman','CEO, OpenAI','@sama','@sama','https://pbs.twimg.com/profile_images/1843893113242415104/_adMgDjA_400x400.jpg','https://pbs.twimg.com/profile_images/1843893113242415104/_adMgDjA_400x400.jpg','Tech',320,680,0,0,0),
  ('Mark Zuckerberg','CEO, Meta','@zuck','@finkd','https://pbs.twimg.com/profile_images/1822982765685108736/XQ2WBq7E_400x400.jpg','https://pbs.twimg.com/profile_images/1822982765685108736/XQ2WBq7E_400x400.jpg','Tech',470,530,0,0,0),
  -- Politics
  ('Donald Trump','45th & 47th President','@realDonaldTrump','@realDonaldTrump','https://pbs.twimg.com/profile_images/874276197357596672/kUuht00m_400x400.jpg','https://pbs.twimg.com/profile_images/874276197357596672/kUuht00m_400x400.jpg','Politics',450,550,0,0,0),
  -- Entertainment
  ('Drake','OVO · 6 God','@Drake','@Drake','https://pbs.twimg.com/profile_images/1788574997213835264/1Z2FGI0i_400x400.jpg','https://pbs.twimg.com/profile_images/1788574997213835264/1Z2FGI0i_400x400.jpg','Entertainment',410,590,0,0,0)
on conflict (x_handle) do nothing;

-- Reset volumes/holders and refresh avatar URLs for any pre-existing rows so
-- re-running the schema wipes stale fake stats. Trades will rebuild these.
update markets set volume_24h = 0, total_volume = 0, holders = 0
  where volume_24h <> 0 or total_volume <> 0 or holders <> 0;

update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/jk7sz6p9e8pozpiudiipj.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/jk7sz6p9e8pozpiudiipj.png' where x_handle = '@elonmusk';
update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/ov3iy2irr6511okrda3uj.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/ov3iy2irr6511okrda3uj.png' where x_handle = '@taylorswift13';
update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/y1eg93i4ejp56w7x6eyhm.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/y1eg93i4ejp56w7x6eyhm.png' where x_handle = '@MrBeast';
update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/d8h5vnqfaf6mxpa6e3sn6.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/d8h5vnqfaf6mxpa6e3sn6.png' where x_handle = '@KingJames';
update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/4u8tjahknefpfkqqnnolh.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/4u8tjahknefpfkqqnnolh.png' where x_handle = '@VitalikButerin';
update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/8p8nyb5cjoiyedm531mq9.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/8p8nyb5cjoiyedm531mq9.png' where x_handle = '@AOC';
update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/snv3l7esbs1t35nist6ao.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/snv3l7esbs1t35nist6ao.png' where x_handle = '@charlidamelio';
update markets set image_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/g7d124v0loog19flgnndi.png', avatar_url = 'https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/g7d124v0loog19flgnndi.png' where x_handle = '@bfrfrfrfr';

-- Seed a single initial price_history point per market so charts have an
-- anchor; real trades append more points via execute_trade().
insert into price_history (market_id, believe_price, doubt_price)
select m.id,
       m.doubt_pool / nullif(m.believe_pool + m.doubt_pool, 0),
       m.believe_pool / nullif(m.believe_pool + m.doubt_pool, 0)
from markets m
where not exists (select 1 from price_history ph where ph.market_id = m.id);

-- ----------------- RPC: list markets with embedded history -----------------
create or replace function get_markets()
returns json
language sql
stable
as $$
  select coalesce(json_agg(row_to_json(r) order by r."createdAt"), '[]'::json)
  from (
    select
      m.id,
      m.name,
      m.title,
      m.handle,
      m.x_handle     as "xHandle",
      m.image_url    as "imageURL",
      m.avatar_url   as "avatarURL",
      m.category,
      m.believe_pool as "believePool",
      m.doubt_pool   as "doubtPool",
      m.volume_24h   as "volume24h",
      m.total_volume as "totalVolume",
      m.holders,
      m.created_at   as "createdAt",
      coalesce((
        select json_agg(json_build_object(
          'id', ph.id,
          'date', ph.ts,
          'believePrice', ph.believe_price,
          'doubtPrice',   ph.doubt_price
        ) order by ph.ts)
        from price_history ph where ph.market_id = m.id
      ), '[]'::json) as "priceHistory"
    from markets m
  ) r;
$$;

-- ----------------- RPC: get portfolio -----------------
create or replace function get_portfolio(p_wallet text)
returns json
language plpgsql
stable
as $$
declare
  v_bal double precision;
begin
  select balance into v_bal from wallets where address = p_wallet;
  if v_bal is null then v_bal := 0; end if;

  return json_build_object(
    'balance', v_bal,
    'positions', coalesce((
      select json_agg(json_build_object(
        'id', p.id,
        'marketId', p.market_id,
        'side', p.side,
        'shares', p.shares,
        'avgCost', p.avg_cost,
        'totalInvested', p.total_invested
      )) from positions p where p.wallet = p_wallet and p.shares > 0.0001
    ), '[]'::json),
    'trades', coalesce((
      select json_agg(json_build_object(
        'id', t.id,
        'marketId', t.market_id,
        'side', t.side,
        'amount', case when t.is_buy then t.amount else -t.amount end,
        'shares', case when t.is_buy then t.shares else -t.shares end,
        'pricePerShare', t.price,
        'timestamp', t.ts
      ) order by t.ts desc) from trades t where t.wallet = p_wallet
    ), '[]'::json)
  );
end;
$$;

-- ----------------- RPC: deposit -----------------
create or replace function deposit(p_wallet text, p_amount double precision)
returns json
language plpgsql
as $
declare
  v_bal double precision;
begin
  if p_amount <= 0 then raise exception 'invalid_amount'; end if;
  insert into wallets(address, balance) values (p_wallet, p_amount)
    on conflict (address) do update set balance = wallets.balance + excluded.balance;
  select balance into v_bal from wallets where address = p_wallet;
  return json_build_object('balance', v_bal);
end;
$;

-- ----------------- PROFILES -----------------
create table if not exists profiles (
  wallet text primary key,
  username text not null default '',
  bio text not null default '',
  avatar_url text not null default '',
  updated_at timestamptz not null default now()
);
alter table profiles enable row level security;
drop policy if exists "read profiles" on profiles;
create policy "read profiles" on profiles for select using (true);

create or replace function get_profile(p_wallet text)
returns json language sql stable as $
  select json_build_object(
    'wallet', p_wallet,
    'username', coalesce((select username from profiles where wallet = p_wallet), ''),
    'bio', coalesce((select bio from profiles where wallet = p_wallet), ''),
    'avatarURL', coalesce((select avatar_url from profiles where wallet = p_wallet), '')
  );
$;

create or replace function upsert_profile(
  p_wallet text, p_username text, p_bio text, p_avatar_url text
) returns json
language plpgsql as $
begin
  insert into profiles(wallet, username, bio, avatar_url)
    values (p_wallet, p_username, p_bio, p_avatar_url)
  on conflict (wallet) do update set
    username = excluded.username,
    bio = excluded.bio,
    avatar_url = excluded.avatar_url,
    updated_at = now();
  return json_build_object(
    'wallet', p_wallet,
    'username', p_username,
    'bio', p_bio,
    'avatarURL', p_avatar_url
  );
end;
$;

-- ----------------- RPC: top traders -----------------
create or replace function get_top_traders()
returns json language sql stable as $
  select coalesce(json_agg(row_to_json(r) order by r.volume desc), '[]'::json)
  from (
    select
      t.wallet,
      coalesce(p.username, '') as username,
      coalesce(p.avatar_url, '') as "avatarURL",
      sum(t.amount)::double precision as volume,
      count(*)::int as "tradeCount",
      sum(case when t.is_buy then 0 else t.amount end)::double precision -
        sum(case when t.is_buy then t.amount else 0 end)::double precision as "realizedPnL"
    from trades t
    left join profiles p on p.wallet = t.wallet
    group by t.wallet, p.username, p.avatar_url
    order by volume desc
    limit 50
  ) r;
$;

-- ----------------- RPC: withdraw -----------------
create or replace function withdraw(p_wallet text, p_amount double precision)
returns json
language plpgsql
as $
declare
  v_bal double precision;
begin
  if p_amount <= 0 then raise exception 'invalid_amount'; end if;
  select balance into v_bal from wallets where address = p_wallet for update;
  if v_bal is null or v_bal < p_amount then raise exception 'insufficient_balance'; end if;
  update wallets set balance = balance - p_amount where address = p_wallet;
  select balance into v_bal from wallets where address = p_wallet;
  return json_build_object('balance', v_bal);
end;
$;

-- ----------------- LEVERAGED POSITIONS -----------------
create table if not exists leveraged_positions (
  id uuid primary key default gen_random_uuid(),
  wallet text not null,
  market_id uuid not null references markets(id) on delete cascade,
  side text not null check (side in ('Believe','Doubt')),
  leverage double precision not null,
  collateral double precision not null,
  size double precision not null,
  entry_price double precision not null,
  liquidation_price double precision not null,
  status text not null default 'open' check (status in ('open','closed','liquidated')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  close_pnl double precision
);
create index if not exists lev_wallet_status on leveraged_positions(wallet, status);
alter table leveraged_positions enable row level security;
drop policy if exists "read lev" on leveraged_positions;
create policy "read lev" on leveraged_positions for select using (true);

-- Maintenance margin: get liquidated when equity hits ~0.5% of collateral
create or replace function _current_price(p_market_id uuid, p_side text)
returns double precision language sql stable as $
  select case when p_side = 'Believe'
              then m.doubt_pool / nullif(m.believe_pool + m.doubt_pool, 0)
              else m.believe_pool / nullif(m.believe_pool + m.doubt_pool, 0)
         end
  from markets m where m.id = p_market_id;
$;

create or replace function open_leverage(
  p_wallet text, p_market_id uuid, p_side text,
  p_leverage double precision, p_collateral double precision
) returns json language plpgsql as $
declare
  entry double precision;
  liq double precision;
  sz double precision;
  v_bal double precision;
  new_id uuid;
  mm double precision := 0.005;
begin
  if p_side not in ('Believe','Doubt') then raise exception 'bad_side'; end if;
  if p_leverage < 2 or p_leverage > 50 then raise exception 'bad_leverage'; end if;
  if p_collateral <= 0 then raise exception 'invalid_amount'; end if;

  insert into wallets(address, balance) values (p_wallet, 0)
    on conflict (address) do nothing;
  select balance into v_bal from wallets where address = p_wallet for update;
  if v_bal < p_collateral then raise exception 'insufficient_balance'; end if;

  entry := _current_price(p_market_id, p_side);
  if entry is null or entry <= 0 then raise exception 'bad_price'; end if;

  sz := p_collateral * p_leverage;
  liq := entry * (1.0 - (1.0 - mm) / p_leverage);

  update wallets set balance = balance - p_collateral where address = p_wallet;

  insert into leveraged_positions(wallet, market_id, side, leverage, collateral, size, entry_price, liquidation_price)
    values (p_wallet, p_market_id, p_side, p_leverage, p_collateral, sz, entry, liq)
    returning id into new_id;

  return json_build_object(
    'id', new_id, 'entryPrice', entry, 'liquidationPrice', liq,
    'size', sz, 'balance', (select balance from wallets where address = p_wallet)
  );
end;
$;

create or replace function close_leverage(p_wallet text, p_id uuid)
returns json language plpgsql as $
declare
  pos record;
  mark double precision;
  pnl double precision;
  payout double precision;
begin
  select * into pos from leveraged_positions where id = p_id and wallet = p_wallet for update;
  if not found then raise exception 'not_found'; end if;
  if pos.status <> 'open' then raise exception 'already_closed'; end if;

  mark := _current_price(pos.market_id, pos.side);
  pnl := pos.size * (mark - pos.entry_price) / pos.entry_price;
  payout := greatest(0, pos.collateral + pnl);

  update wallets set balance = balance + payout where address = p_wallet;
  update leveraged_positions set status = 'closed', closed_at = now(), close_pnl = pnl where id = p_id;

  return json_build_object(
    'pnl', pnl, 'payout', payout,
    'balance', (select balance from wallets where address = p_wallet)
  );
end;
$;

-- Liquidate all underwater positions. Called defensively on portfolio reads.
create or replace function liquidate_underwater()
returns int language plpgsql as $
declare
  pos record;
  mark double precision;
  n int := 0;
begin
  for pos in select * from leveraged_positions where status = 'open' loop
    mark := _current_price(pos.market_id, pos.side);
    if mark is not null and mark <= pos.liquidation_price then
      update leveraged_positions set status='liquidated', closed_at=now(), close_pnl = -pos.collateral where id = pos.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$;

create or replace function get_leverage(p_wallet text)
returns json language plpgsql stable as $
begin
  return coalesce((
    select json_agg(row_to_json(r) order by r.opened_at desc) from (
      select
        lp.id, lp.market_id as "marketId", lp.side,
        lp.leverage, lp.collateral, lp.size,
        lp.entry_price as "entryPrice",
        lp.liquidation_price as "liquidationPrice",
        lp.status, lp.opened_at, lp.closed_at,
        lp.close_pnl as "closePnL"
      from leveraged_positions lp
      where lp.wallet = p_wallet
      order by lp.opened_at desc
      limit 100
    ) r
  ), '[]'::json);
end;
$;

-- ----------------- RPC: execute_trade (atomic AMM) -----------------
create or replace function execute_trade(
  p_wallet    text,
  p_market_id uuid,
  p_side      text,
  p_is_buy    boolean,
  p_amount    double precision,   -- SOL in (buy) OR ignored
  p_shares    double precision    -- shares out (ignored on buy) / shares to sell
) returns json
language plpgsql
as $$
declare
  m record;
  fee_rate double precision := 0.01;
  fee double precision;
  amt_after_fee double precision;
  shares_out double precision;
  gross_payout double precision;
  net_payout double precision;
  avg_price double precision;
  new_believe double precision;
  new_doubt double precision;
  k double precision;
  v_bal double precision;
begin
  if p_side not in ('Believe','Doubt') then raise exception 'bad_side'; end if;

  -- lock market row
  select * into m from markets where id = p_market_id for update;
  if not found then raise exception 'market_not_found'; end if;

  -- ensure wallet row exists
  insert into wallets(address, balance) values (p_wallet, 0)
    on conflict (address) do nothing;

  k := m.believe_pool * m.doubt_pool;

  if p_is_buy then
    if p_amount <= 0 then raise exception 'invalid_amount'; end if;
    select balance into v_bal from wallets where address = p_wallet for update;
    if v_bal < p_amount then raise exception 'insufficient_balance'; end if;

    fee := p_amount * fee_rate;
    amt_after_fee := p_amount - fee;

    if p_side = 'Believe' then
      new_doubt   := m.doubt_pool + amt_after_fee;
      new_believe := k / new_doubt;
      shares_out  := m.believe_pool - new_believe;
    else
      new_believe := m.believe_pool + amt_after_fee;
      new_doubt   := k / new_believe;
      shares_out  := m.doubt_pool - new_believe; -- bug guard below
      shares_out  := m.doubt_pool - new_doubt;
    end if;

    avg_price := p_amount / shares_out;

    update markets set
      believe_pool = new_believe,
      doubt_pool   = new_doubt,
      volume_24h   = volume_24h + p_amount,
      total_volume = total_volume + p_amount
    where id = p_market_id;

    update wallets set balance = balance - p_amount where address = p_wallet;

    -- upsert position
    insert into positions(wallet, market_id, side, shares, avg_cost, total_invested)
      values (p_wallet, p_market_id, p_side, shares_out, avg_price, p_amount)
    on conflict (wallet, market_id, side) do update set
      shares         = positions.shares + excluded.shares,
      total_invested = positions.total_invested + excluded.total_invested,
      avg_cost       = (positions.total_invested + excluded.total_invested) / (positions.shares + excluded.shares);

    insert into trades(wallet, market_id, side, is_buy, amount, shares, price)
      values (p_wallet, p_market_id, p_side, true, p_amount, shares_out, avg_price);

    insert into price_history(market_id, believe_price, doubt_price)
      values (p_market_id, new_doubt/(new_believe+new_doubt), new_believe/(new_believe+new_doubt));

    select balance into v_bal from wallets where address = p_wallet;
    return json_build_object(
      'shares', shares_out, 'avgPrice', avg_price, 'fee', fee,
      'balance', v_bal, 'amount', p_amount
    );

  else
    -- SELL
    if p_shares <= 0 then raise exception 'invalid_amount'; end if;

    -- check position
    declare
      pos record;
    begin
      select * into pos from positions
        where wallet=p_wallet and market_id=p_market_id and side=p_side for update;
      if not found or pos.shares < p_shares - 0.000001 then
        raise exception 'insufficient_shares';
      end if;
    end;

    if p_side = 'Believe' then
      new_believe := m.believe_pool + p_shares;
      new_doubt   := k / new_believe;
      gross_payout := m.doubt_pool - new_doubt;
    else
      new_doubt   := m.doubt_pool + p_shares;
      new_believe := k / new_doubt;
      gross_payout := m.believe_pool - new_believe;
    end if;

    fee := gross_payout * fee_rate;
    net_payout := gross_payout - fee;
    avg_price := net_payout / p_shares;

    update markets set
      believe_pool = new_believe,
      doubt_pool   = new_doubt,
      volume_24h   = volume_24h + gross_payout,
      total_volume = total_volume + gross_payout
    where id = p_market_id;

    update wallets set balance = balance + net_payout where address = p_wallet;

    -- reduce / remove position
    update positions set
      shares         = shares - p_shares,
      total_invested = total_invested - (avg_cost * p_shares)
    where wallet = p_wallet and market_id = p_market_id and side = p_side;

    delete from positions
      where wallet = p_wallet and market_id = p_market_id and side = p_side and shares <= 0.0001;

    insert into trades(wallet, market_id, side, is_buy, amount, shares, price)
      values (p_wallet, p_market_id, p_side, false, net_payout, p_shares, avg_price);

    insert into price_history(market_id, believe_price, doubt_price)
      values (p_market_id, new_doubt/(new_believe+new_doubt), new_believe/(new_believe+new_doubt));

    select balance into v_bal from wallets where address = p_wallet;
    return json_build_object(
      'shares', p_shares, 'avgPrice', avg_price, 'fee', fee,
      'balance', v_bal, 'payout', net_payout
    );
  end if;
end;
$$;
