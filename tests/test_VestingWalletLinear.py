import brownie
from pytest import approx

from util.base18 import toBase18
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
    beneficiary = address1
    start_ts = chain.time()
    ts_duration = 4

    # constructor
    vw = BROWNIE_PROJECT.VestingWalletLinear.deploy(
        beneficiary,
        start_ts,
        ts_duration,
        {"from": account0},
    )

    assert vw.beneficiary() == beneficiary
    start_block_measured = vw.start()
    assert start_block_measured in [start_ts - 1, start_ts, start_ts + 1]
    assert vw.duration() == 4
    assert vw.released() == 0

    # time passes
    chain.mine(blocks=15, timedelta=1)
    assert vw.released() == 0  # haven't released anything

    # call release
    vw.release()
    assert vw.released() == 0  # wallet never got funds to release!


def test_ethFunding():
    # ensure each account has exactly 30 ETH
    for account in [account0, account1, account2]:
        account.transfer(GOD_ACCOUNT, account.balance())
        GOD_ACCOUNT.transfer(account, toBase18(30.0))

    # account0 should be able to freely transfer ETH
    account0.transfer(account1, toBase18(1.0))
    account1.transfer(account0, toBase18(1.0))
    assert account0.balance() / 1e18 == approx(30.0)
    assert account1.balance() / 1e18 == approx(30.0)

    # set up vesting wallet (account). It vests all ETH/tokens that it receives.
    # where beneficiary is account1
    start_ts = start_ts = chain.time()
    ts_duration = 5
    wallet = BROWNIE_PROJECT.VestingWalletLinear.deploy(
        address1,
        start_ts,
        ts_duration,
        {"from": account0},
    )
    assert wallet.balance() == 0

    # send ETH to the wallet. It has a function:
    #    receive() external payable virtual {}
    # which allows it to receive ETH. It's called for plain ETH transfers,
    # ie every call with empty calldata.
    # https://medium.com/coinmonks/solidity-v0-6-0-is-here-things-you-should-know-7d4ab5bca5f1
    assert account0.transfer(wallet.address, toBase18(30.0))
    assert wallet.balance() / 1e18 == approx(30.0)
    assert account0.balance() / 1e18 == approx(0.0)
    assert account1.balance() / 1e18 == approx(30.0)  # unchanged so far
    assert wallet.vestedAmount(start_ts) == 0
    assert wallet.vestedAmount(start_ts + 10) > 0.0
    assert wallet.released() == 0

    # make enough time pass for everything to vest
    chain.mine(blocks=14, timedelta=100)

    assert wallet.vestedAmount(1) == 0
    assert wallet.vestedAmount(2) == 0
    assert wallet.vestedAmount(3) == 0
    assert wallet.vestedAmount(start_ts) == 0
    assert wallet.vestedAmount(start_ts + 1) / 1e18 == approx(6.0)
    assert wallet.vestedAmount(start_ts + 2) / 1e18 == approx(12.0)
    assert wallet.vestedAmount(start_ts + 3) / 1e18 == approx(18.0)
    assert wallet.vestedAmount(start_ts + 4) / 1e18 == approx(24.0)
    assert wallet.vestedAmount(start_ts + 5) / 1e18 == approx(30.0)
    assert wallet.vestedAmount(start_ts + 6) / 1e18 == approx(30.0)
    assert wallet.vestedAmount(start_ts + 7) / 1e18 == approx(30.0)

    assert wallet.released() == 0
    assert account1.balance() / 1e18 == approx(30.0)  # not released yet!

    # release the ETH. Anyone can call it
    wallet.release({"from": account2})
    assert wallet.released() / 1e18 == approx(30.0)  # now it's released!
    assert account1.balance() / 1e18 == approx(30.0 + 30.0)  # beneficiary richer

    # put some new ETH into wallet. It's immediately vested, but not released
    account2.transfer(wallet.address, toBase18(10.0))
    assert wallet.vestedAmount(chain.time()) / 1e18 == approx(30.0 + 10.0)
    assert wallet.released() / 1e18 == approx(30.0 + 0.0)  # not released yet!

    # release the new ETH
    wallet.release({"from": account3})
    assert wallet.released() / 1e18 == approx(30.0 + 10.0)  # new ETH is released!
    assert account1.balance() / 1e18 == approx(30.0 + 30.0 + 10.0)  # +10 eth to ben


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
    start_ts = chain.time()
    ts_duration = 5
    wallet = BROWNIE_PROJECT.VestingWalletLinear.deploy(
        address1,
        start_ts,
        ts_duration,
        {"from": account0},
    )
    assert token.balanceOf(wallet) == 0

    # send TOK to the wallet
    token.transfer(wallet.address, toBase18(30.0), {"from": account0})
    assert token.balanceOf(wallet) / 1e18 == approx(30.0)
    assert token.balanceOf(account0) / 1e18 == approx(60.0)
    assert token.balanceOf(account1) / 1e18 == approx(110.0)
    assert wallet.vestedAmount(taddress, start_ts) == 0
    assert wallet.vestedAmount(taddress, start_ts + 6) > 0.0
    assert wallet.released(taddress) == 0

    # make enough time pass for everything to vest
    chain.sleep(14)
    chain.mine(1)

    assert wallet.vestedAmount(taddress, start_ts - 3) == 0
    assert wallet.vestedAmount(taddress, start_ts - 2) == 0
    assert wallet.vestedAmount(taddress, start_ts - 1) == 0
    assert wallet.vestedAmount(taddress, start_ts) == 0
    assert wallet.vestedAmount(taddress, start_ts + 1) / 1e18 == approx(6.0)
    assert wallet.vestedAmount(taddress, start_ts + 2) / 1e18 == approx(12.0)
    assert wallet.vestedAmount(taddress, start_ts + 3) / 1e18 == approx(18.0)
    assert wallet.vestedAmount(taddress, start_ts + 4) / 1e18 == approx(24.0)
    assert wallet.vestedAmount(taddress, start_ts + 5) / 1e18 == approx(30.0)
    assert wallet.vestedAmount(taddress, start_ts + 6) / 1e18 == approx(30.0)
    assert wallet.vestedAmount(taddress, start_ts + 7) / 1e18 == approx(30.0)

    assert wallet.released(taddress) == 0
    assert token.balanceOf(account1) / 1e18 == approx(110.0)  # not released yet

    # release the TOK. Anyone can call it
    wallet.release(taddress, {"from": account2})
    assert wallet.released(taddress) / 1e18 == approx(30.0)  # released!
    assert token.balanceOf(account1) / 1e18 == approx(
        110.0 + 30.0
    )  # beneficiary richer

    # put some new TOK into wallet. It's immediately vested, but not released
    token.transfer(wallet.address, toBase18(10.0), {"from": account2})
    assert wallet.vestedAmount(taddress, toBase18(11)) / 1e18 == approx(30.0 + 10.0)
    assert wallet.released(taddress) / 1e18 == approx(30.0)  # not released yet

    # release the new TOK
    wallet.release(taddress, {"from": account3})
    assert wallet.released(taddress) / 1e18 == approx(30.0 + 10.0)  # TOK released!
    assert token.balanceOf(account1) / 1e18 == approx(
        110 + 30 + 10.0
    )  # beneficiary richer
