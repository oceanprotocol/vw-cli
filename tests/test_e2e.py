import brownie
from pytest import approx

from util.base18 import fromBase18, toBase18
from util.constants import BROWNIE_PROJECTaccounts = brownie.network.accounts

account0, account1, account2, account3 = (
    accounts[0],
    accounts[1],
    accounts[2],
    accounts[3],
)
address0, address1, address2 = account0.address, account1.address, account2.address
chain = brownie.network.chain
GOD_ACCOUNT = accounts[9]
TOT_SUPPLY = 10000
R_SUPPLIES = [TOT_SUPPLY * 0.1, TOT_SUPPLY * 0.15, TOT_SUPPLY * 0.25, TOT_SUPPLY * 0.5] # FOR EACH RATCHET
R_DURATIONS_MONTH = [6,6,6,100] # DURATION IN MONTH
R_DURATIONS = [i * 30 * 24 * 60 * 60 for i in R_DURATIONS_MONTH] # DURATION IN SECONDS

def test_e2e():
    # accounts 0, 1, 2 should each start with 100 TOK
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TOK", "Test Token", 18, TOT_SUPPLY, {"from": account0}
    )
    taddress = token.address
    
    for ratchet_i in range(len(R_SUPPLIES)):
        # set up vesting wallet (account). It vests all ETH/tokens that it receives.
        start_ts = chain.time()
        SUPPLY = R_SUPPLIES[ratchet_i]
        DURATION = R_DURATIONS[ratchet_i]
        # 4 years
        half_life = 4 * 365 * 24 * 60 * 60 # half life is 4 years
        wallet = BROWNIE_PROJECT.VestingWalletHalving.deploy(
            address1,
            start_ts,
            half_life,
            {"from": account0},
        )
        assert token.balanceOf(wallet) == 0
        # send TOK to the wallet
        token.transfer(wallet.address, R_SUPPLIES[ratchet_i], {"from": account0})

        # Check balances
        assert token.balanceOf(wallet) / 1e18 == approx(SUPPLY)

        # Check vested amounts
        assert wallet.vestedAmount(taddress, start_ts) == 0
        assert wallet.vestedAmount(taddress, start_ts + 10) > 0.0

        points = [int(DURATION / 100) * i for i in range(101)]

        for i in points:
            contract_amt = fromBase18(wallet.vestedAmount(taddress, start_ts + i))
            approx_amt = _approx(SUPPLY, i, half_life)
            assert contract_amt == approx(
                approx_amt, 1e-5
            ), f"{i} {contract_amt} {approx_amt}"

        assert wallet.released(taddress) == 0

        points = [points[i] - points[i - 1] for i in range(1, len(points))]
        for i in points:
            # forward time and test
            chain.sleep(i)
            contract_amt = wallet.releasable(taddress)
            balance_before = fromBase18(token.balanceOf(account1))
            rel_before = wallet.released(taddress)
            tx = wallet.release(taddress, {"from": account1})
            amount = tx.events["Released"]["amount"]
            balance_after = fromBase18(token.balanceOf(account1))
            rel_after = wallet.released(taddress)
            assert balance_after - balance_before == fromBase18(amount)
            assert rel_after - rel_before == fromBase18(amount)
            assert wallet.released(taddress) == amount
            assert contract_amt == amount

def _approx(value, t, h):
    t = int(t)
    h = int(h)
    value = int(value)
    p = value >> int(t / h)
    t %= h
    return value - p + (p * t) / h / 2
