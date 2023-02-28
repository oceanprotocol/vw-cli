import brownie

from util.constants import BROWNIE_PROJECT

accounts = brownie.network.accounts


def test_shares():
    token = _deployToken()
    alice = accounts[0]
    bob = accounts[1]
    carol = accounts[2]
    shares = [100, 200, 300]

    router = _deployRouter(shares, [alice, bob, carol])
    token.transfer(router, 600, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 200
    assert router.shares(carol) == 300

    assert router.totalShares() == 600

    # remove bob
    router.removePayee(bob, {"from": alice})
    assert router.shares(alice) == 100
    assert router.shares(bob) == 0
    assert router.shares(carol) == 300

    assert router.totalShares() == 400

    # adjuts carol's shares

    router.adjustShare(carol, 100, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 0
    assert router.shares(carol) == 100

    assert router.totalShares() == 200

    router.addPayee(bob, 200, {"from": alice})
    alice_before = token.balanceOf(alice)
    router.release(token.address, {"from": carol})
    alice_after = token.balanceOf(alice)

    assert alice_after - alice_before == 150
    assert token.balanceOf(bob) == 300
    assert token.balanceOf(carol) == 150

    router.removePayee(alice, {"from": alice})
    router.removePayee(carol, {"from": alice})
    router.removePayee(bob, {"from": alice})

    router.addPayee(accounts[3], 1000, {"from": alice})
    assert router.shares(accounts[3]) == 1000
    assert router.totalShares() == 1000

    router.release(token.address, {"from": carol})
    assert token.balanceOf(accounts[3]) == 0


def _deployRouter(shares, addresses):
    return BROWNIE_PROJECT.Router.deploy(addresses, shares, {"from": accounts[0]})


def _deployToken():
    return BROWNIE_PROJECT.Simpletoken.deploy(
        "TST", "Test Token", 18, 1e21, {"from": accounts[0]}
    )
