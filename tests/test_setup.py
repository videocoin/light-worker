import pytest

from brownie import GatingNft1155, LightWorkerDao, accounts

@pytest.fixture(scope="session")
def nft():
    return accounts[0].deploy(GatingNft1155, "TestURI")

def test_mint(nft, accounts):
    nft.mint(accounts[1],1,1000, 0x1234, {'from': accounts[1]})
    assert nft.balanceOf(accounts[1], 1) == 1000

def test_dao(nft, accounts):
    daoAddr=nft.getLightWorkerDao(1)
    dao=LightWorkerDao.at(daoAddr)
    dao.setTokenPrice(50, {'from': accounts[1]})
    assert dao.getTokenPrice() == 50
    dao.acquireToken( {'from':accounts[2], 'value': "50 wei"})
    assert nft.balanceOf(accounts[2], 1) == 1
    nft.setApprovalForAll(daoAddr, 1, {'from':accounts[2]})
    dao.releaseToken( {'from':accounts[2]})
    assert nft.balanceOf(accounts[2], 1) == 0