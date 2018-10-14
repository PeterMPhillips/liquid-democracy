var BigNumber = require('bignumber.js');

const LiquidDAO = artifacts.require("./LiquidDAO.sol");

const ETH = 1000000000000000000;

contract('Liquid DAO Contract', async() => {
  const owner = web3.eth.accounts[0];
  const user1 = web3.eth.accounts[1];
  const user2 = web3.eth.accounts[2];
  const user3 = web3.eth.accounts[3];
  const user4 = web3.eth.accounts[4];
  const user5 = web3.eth.accounts[5];
  const user6 = web3.eth.accounts[6];
  const user7 = web3.eth.accounts[7];
  const user8 = web3.eth.accounts[8];
  const user9 = web3.eth.accounts[9];

  let dao;
  let voteID;

  it('Deploy contract', async() => {
    dao = await LiquidDAO.new(50);
  });

  it('Onboard users', async() => {
    for(var i=1; i<web3.eth.accounts.length; i++){
      await dao.onboard(web3.eth.accounts[i]);
    }
    console.log('Total Users: ', Number(await dao.getTotalUsers()));
    console.log('Fraction: ', Number(await dao.getFraction()));
  });

  it('Delegate users', async() => {
    /*
    await dao.delegateTo(owner, {from:user1});
    await dao.delegateTo(user1, {from:user2});
    await dao.delegateTo(user3, {from:user4});
    await dao.delegateTo(user3, {from:user5});
    await dao.delegateTo(user2, {from:user6});
    */
    for(var i=1; i<web3.eth.accounts.length; i++){
      await dao.delegateTo(web3.eth.accounts[i-1], {from:web3.eth.accounts[i]});
    }
  });

  it('View votes', async() => {
    for(var i=0; i<web3.eth.accounts.length; i++){
      console.log(Number(await dao.getVotes(web3.eth.accounts[i])));
    }
  });

  it('Fail to delegate', async() => {
    let err;
    try{
      await dao.delegateTo(user2, {from:owner}); //This should fail since owner will loop back on themselves
    } catch(e){
      err = e;
    }
    assert.notEqual(err, undefined);
  });

  it('Initiate transfer', async() => {
    tx = await dao.initiateTransfer(owner, 1*ETH, 0);
    voteID = tx.logs[0].args.voteID;
    console.log(voteID);
  });

  it('Vote', async() => {
    await dao.voteFor(voteID, {from: owner});
    await dao.voteFor(voteID, {from: user1});
    await dao.voteFor(voteID, {from: user2});
    //await dao.voteFor(voteID, {from: user3});
  });

  it('Query Votes', async() => {
    let tx = await dao.queryVotes(voteID);
    console.log(Number(tx.logs[0].args.count));
  });
});
