import brownie
from pytest import approx

from util.base18 import fromBase18, toBase18
from util.constants import BROWNIE_PROJECT

accounts = brownie.network.accounts
account0, account1, account2, account3 = (
    accounts[0],
    accounts[1],
    accounts[2],
    accounts[3],
)
address0, address1, address2 = account0.address, account1.address, account2.address
chain = brownie.network.chain
GOD_ACCOUNT = accounts[9]


def test_basic():
    n_blocks = len(chain)
    beneficiary = address1
    start_block = n_blocks + 1
    half_life = 50

    # constructor
    vw = BROWNIE_PROJECT.VestingWalletHalving.deploy(
        beneficiary,
        toBase18(start_block),
        half_life,
        {"from": account0},
    )

    assert vw.beneficiary() == beneficiary
    start_block_measured = int(vw.startBlock() / 1e18)
    assert start_block_measured in [start_block - 1, start_block, start_block + 1]
    assert vw.released() == 0

    # time passes
    chain.mine(blocks=15, timedelta=1)
    assert vw.released() == 0  # haven't released anything

    # call release
    vw.release()
    assert vw.released() == 0  # wallet never got funds to release!


def test_tokenFunding():
    # accounts 0, 1, 2 should each start with 100 TOK
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TOK", "Test Token", 18, toBase18(300.0), {"from": account0}
    )
    token.transfer(account1, toBase18(100.0), {"from": account0})
    token.transfer(account2, toBase18(100.0), {"from": account0})
    taddress = token.address

    assert token.balanceOf(account0) / 1e18 == approx(100.0)
    assert token.balanceOf(account1) / 1e18 == approx(100.0)
    assert token.balanceOf(account2) / 1e18 == approx(100.0)

    # account0 should be able to freely transfer TOK
    token.transfer(account1, toBase18(10.0), {"from": account0})
    assert token.balanceOf(account0) / 1e18 == approx(90.0)
    assert token.balanceOf(account1) / 1e18 == approx(110.0)

    # set up vesting wallet (account). It vests all ETH/tokens that it receives.
    start_block = toBase18(len(chain))
    half_life = toBase18(50)
    half_life_int = int(fromBase18(half_life))
    wallet = BROWNIE_PROJECT.VestingWalletHalving.deploy(
        address1,
        start_block,
        half_life,
        {"from": account0},
    )
    assert token.balanceOf(wallet) == 0

    # send TOK to the wallet
    token.transfer(wallet.address, toBase18(30.0), {"from": account0})

    # Check balances
    assert token.balanceOf(wallet) / 1e18 == approx(30.0)
    assert token.balanceOf(account0) / 1e18 == approx(60.0)
    assert token.balanceOf(account1) / 1e18 == approx(110.0)

    # Check vested amounts
    assert wallet.vestedAmount(taddress, start_block) == 0
    assert wallet.vestedAmount(taddress, toBase18(10) + start_block) > 0.0
    assert wallet.released(taddress) == 0

    assert wallet.vestedAmount(taddress, toBase18(1)) == 0
    assert wallet.vestedAmount(taddress, toBase18(2)) == 0
    assert wallet.vestedAmount(taddress, toBase18(3)) == 0
    assert wallet.vestedAmount(taddress, toBase18(4)) == 0
    assert wallet.vestedAmount(taddress, start_block + half_life) == toBase18(15.0)

    assert wallet.vestedAmount(taddress, start_block + toBase18(30)) == toBase18(
        _approx(30.0, 30, 50)
    )

    for i in range(half_life_int):
        contract_amt = fromBase18(
            wallet.vestedAmount(taddress, start_block + toBase18(i))
        )
        approx_amt = _approx(30.0, i, half_life_int)
        assert contract_amt == approx(
            approx_amt, 1e-5
        ), f"{i} {contract_amt} {approx_amt}"

    assert wallet.released(taddress) == 0
    assert token.balanceOf(account1) / 1e18 == approx(110.0)  # not released yet

    # forward time and release funds
    chain.mine(blocks=half_life_int - 2, timedelta=1)
    balance_before = token.balanceOf(account1)
    current_vested_amount = wallet.vestedAmount(taddress, toBase18(len(chain)))
    assert fromBase18(current_vested_amount) == approx(15.0)

    tx = wallet.release(taddress, {"from": account1})
    # get event
    event = tx.events["ERC20Released"]
    amount = event["amount"]
    assert fromBase18(amount) == approx(fromBase18(current_vested_amount))
    assert fromBase18(token.balanceOf(account1)) == approx(
        fromBase18(balance_before + toBase18(15.0))
    )  # released!

    # forward time and release most of the funds
    chain.mine(blocks=500, timedelta=1)

    # release the TOK. Anyone can call it
    wallet.release(taddress, {"from": account2})
    assert wallet.released(taddress) / 1e18 == approx(30.0, 0.1)  # released!
    assert token.balanceOf(account1) / 1e18 == approx(
        110.0 + 30.0, 0.1
    )  # beneficiary richer

    # put some new TOK into wallet. It's immediately vested, but not released
    token.transfer(wallet.address, toBase18(10.0), {"from": account2})
    assert wallet.vestedAmount(taddress, start_block + half_life) / 1e18 == approx(
        15.0 + 5.0
    )
    assert wallet.released(taddress) / 1e18 == approx(30.0, 0.1)  # not released yet

    # release the new TOK
    wallet.release(taddress, {"from": account3})
    assert wallet.released(taddress) / 1e18 == approx(30.0 + 10.0, 0.1)  # TOK released!
    assert token.balanceOf(account1) / 1e18 == approx(
        110 + 30 + 10.0, 0.1
    )  # beneficiary richer


def test_tokenFunding_big_supply():
    # supply is 1.41B tokens
    supply = toBase18(1.41e9)

    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TOK", "Test Token", 18, supply, {"from": account0}
    )
    token.transfer(account1, toBase18(100.0), {"from": account0})
    token.transfer(account2, toBase18(100.0), {"from": account0})
    taddress = token.address

    assert token.balanceOf(account1) / 1e18 == approx(100.0)
    assert token.balanceOf(account2) / 1e18 == approx(100.0)

    # set up vesting wallet (account). It vests all ETH/tokens that it receives.
    start_block = toBase18(len(chain))
    half_life = toBase18(50)
    half_life_int = int(fromBase18(half_life))
    wallet = BROWNIE_PROJECT.VestingWalletHalving.deploy(
        address1,
        start_block,
        half_life,
        {"from": account0},
    )
    assert token.balanceOf(wallet) == 0

    # send TOK to the wallet
    token.transfer(wallet.address, token.balanceOf(account0), {"from": account0})

    # Check vested amounts
    assert wallet.vestedAmount(taddress, start_block) == 0
    assert wallet.vestedAmount(taddress, toBase18(10) + start_block) > 0.0
    assert wallet.released(taddress) == 0

    assert wallet.vestedAmount(taddress, toBase18(1)) == 0
    assert wallet.vestedAmount(taddress, toBase18(2)) == 0
    assert wallet.vestedAmount(taddress, toBase18(3)) == 0
    assert wallet.vestedAmount(taddress, toBase18(4)) == 0

    for i in range(half_life_int):
        contract_amt = fromBase18(
            wallet.vestedAmount(taddress, start_block + toBase18(i))
        )
        approx_amt = _approx(fromBase18(supply), i, half_life_int)
        assert contract_amt == approx(
            approx_amt, 1e-5
        ), f"{i} {contract_amt} {approx_amt}"

    assert wallet.released(taddress) == 0
    assert token.balanceOf(account1) == toBase18(100.0)  # not released yet

    # forward time and release funds
    chain.mine(blocks=half_life_int - 2, timedelta=1)
    balance_before = token.balanceOf(account1)
    current_vested_amount = wallet.vestedAmount(taddress, toBase18(len(chain)))
    assert fromBase18(current_vested_amount) == approx(fromBase18(supply / 2))

    tx = wallet.release(taddress, {"from": account1})
    # get event
    event = tx.events["ERC20Released"]
    amount = event["amount"]
    assert fromBase18(amount) == approx(fromBase18(current_vested_amount))
    assert fromBase18(token.balanceOf(account1)) == approx(
        fromBase18(balance_before + supply / 2)
    )  # released!

    # forward time and release most of the funds
    chain.mine(blocks=500, timedelta=1)

    # release the TOK. Anyone can call it
    wallet.release(taddress, {"from": account2})
    assert wallet.released(taddress) / 1e18 == approx(
        fromBase18(supply), 0.1
    )  # released!
    assert token.balanceOf(account1) / 1e18 == approx(
        110.0 + fromBase18(supply), 0.1
    )  # beneficiary richer


def _approx(value, t, h):
    t = int(t)
    h = int(h)
    value = int(value)
    p = value >> int(t / h)
    t %= h
    return value - p + (p * t) / h / 2
