import brownie

from util.constants import BROWNIE_PROJECT

accounts = brownie.network.accounts
alice = accounts[0]
bob = accounts[1]
carol = accounts[2]
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

def test_shares():
    token = _deployToken()
    shares = [100, 200, 300]

    splitter = _deploySplitter(shares, [alice, bob, carol])
    token.transfer(splitter, 600, {"from": alice})

    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 200
    assert splitter.shares(carol) == 300

    assert splitter.totalShares() == 600

    # remove bob
    splitter.removePayee(bob, {"from": alice})
    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 0
    assert splitter.shares(carol) == 300

    assert splitter.totalShares() == 400

    # adjuts carol's shares

    splitter.adjustShare(carol, 100, {"from": alice})

    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 0
    assert splitter.shares(carol) == 100

    assert splitter.totalShares() == 200

    splitter.addPayee(bob, 100, {"from": alice})
    splitter.adjustShare(bob, 200, {"from": alice})
    alice_before = token.balanceOf(alice)
    splitter.release(token.address, {"from": carol})
    alice_after = token.balanceOf(alice)

    assert alice_after - alice_before == 149
    assert token.balanceOf(bob) == 301
    assert token.balanceOf(carol) == 149

    assert splitter.totalReleased(token) == 599
    assert splitter.released(token, alice) == 149
    assert splitter.released(token, bob) == 301
    assert splitter.released(token, carol) == 149

    splitter.removePayee(alice, {"from": alice})
    splitter.removePayee(carol, {"from": alice})
    splitter.removePayee(bob, {"from": alice})

    splitter.addPayee(accounts[3], 1000, {"from": alice})
    assert splitter.shares(accounts[3]) == 1000
    assert splitter.totalShares() == 1000

    splitter.release(token.address, {"from": carol})
    assert token.balanceOf(accounts[3]) == 0


def test_add_zero_shares():
    splitter = _deploySplitter([100], [alice])
    with brownie.reverts("Splitter: shares are 0"):
        splitter.addPayee(bob, 0, {"from": alice})


def test_remove_nonexistent_payee():
    splitter = _deploySplitter([100], [alice])
    with brownie.reverts("Splitter: account has no shares"):
        splitter.removePayee(bob, {"from": alice})


def test_adjust_to_zero():
    splitter = _deploySplitter([100, 200], [alice, bob])
    with brownie.reverts("Splitter: shares are 0"):
        splitter.adjustShare(bob, 0, {"from": alice})


def test_add_payee():
    token = _deployToken()
    shares = [100, 200]

    splitter = _deploySplitter(shares, [alice, bob])
    token.transfer(splitter, 600, {"from": alice})

    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 200

    assert splitter.totalShares() == 300

    splitter.addPayee(carol, 100, {"from": alice})
    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 200
    assert splitter.shares(carol) == 100

    assert splitter.totalShares() == 400


def test_adjust_nonexistent_payee_shares():
    splitter = _deploySplitter([100], [alice])

    with brownie.reverts("Splitter: account has no shares"):
        splitter.adjustShare(bob, 100, {"from": alice})


def test_adjust_payee_shares():
    splitter = _deploySplitter([100, 200, 300], [alice, bob, carol])

    splitter.adjustShare(bob, 100, {"from": alice})

    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 100
    assert splitter.shares(carol) == 300

    assert splitter.totalShares() == 500


def test_remove_payee():
    splitter = _deploySplitter([100, 200], [alice, bob])

    splitter.removePayee(bob, {"from": alice})

    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 0

    assert splitter.totalShares() == 100


def test_admin_functions_only_by_admin():
    splitter = _deploySplitter([100], [alice])

    with brownie.reverts("Ownable: caller is not the owner"):
        splitter.addPayee(bob, 50, {"from": bob})

    with brownie.reverts("Ownable: caller is not the owner"):
        splitter.removePayee(bob, {"from": bob})

    with brownie.reverts("Ownable: caller is not the owner"):
        splitter.adjustShare(bob, 50, {"from": bob})


def test_add_zero_address():
    splitter = _deploySplitter([100], [alice])
    with brownie.reverts("Splitter: zero address"):
        splitter.addPayee(
            ZERO_ADDRESS, 50, {"from": alice}
        )


def test_remove_zero_address():
    splitter = _deploySplitter([100], [alice])
    with brownie.reverts("Splitter: zero address"):
        splitter.removePayee(
            ZERO_ADDRESS, {"from": alice}
        )


def test_adjust_zero_address_shares():
    splitter = _deploySplitter([100], [alice])
    with brownie.reverts("Splitter: zero address"):
        splitter.adjustShare(
            ZERO_ADDRESS, 50, {"from": alice}
        )


def test_readd_payee():
    splitter = _deploySplitter([100, 200], [alice, bob])

    splitter.removePayee(bob, {"from": alice})

    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 0

    assert splitter.totalShares() == 100

    splitter.addPayee(bob, 200, {"from": alice})

    assert splitter.shares(alice) == 100
    assert splitter.shares(bob) == 200

    assert splitter.totalShares() == 300

    with brownie.reverts("Splitter: account already has shares"):
        splitter.addPayee(bob, 200, {"from": alice})



def test_send_eth_to_contract():
    splitter = _deploySplitter([100], [alice])
    with brownie.reverts():
        bob.transfer(splitter, 100)


def _deploySplitter(shares, addresses):
    return BROWNIE_PROJECT.Splitter.deploy(addresses, shares, {"from": accounts[0]})


def _deployToken():
    return BROWNIE_PROJECT.Simpletoken.deploy(
        "TST", "Test Token", 18, 1e21, {"from": accounts[0]}
    )
