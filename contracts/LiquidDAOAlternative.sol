pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./ERC20.sol";

contract LiquidDAOAlternative{
  using SafeMath for *;

  // address[] private users;
  // mapping(address => address) private delegate; //For a given address, who do they delgate to
  // mapping(address => address[]) private delegators; //For a given address, who delegates to them
  // mapping(address => uint) private userVotes; //How many votes a user controls
  // mapping(bytes32 => bool) private successful; //A mapping of which votes have crossed the threshold and can be executed

  struct DelegateTree {
    address top;
    address[] down;   // vote power of this tree is the length of this list
    uint16 votePower;   // tree cannot have more than 2^32 votes (65536)
  }

  mapping (address => DelegateTree) public tree;   // Every user is the top of their own tree

  mapping(address => bool) private auth; //A mapping of who is authorized in the organization
  mapping(bytes32 => uint128) private vote; //A mapping of voting issues and who has voted for them
  uint8 threshold;
  uint128 public numUsers;   // can't have more than 2^128 users


  constructor(uint8 _threshold) public {
    require(_threshold < 100);
    threshold = _threshold;
    auth[msg.sender] = true;
    DelegateTree storage firstTree = tree[msg.sender];
    firstTree.votePower = 1;
  }

  function voteFor(bytes32 _voteID)
  external {
    require(auth[msg.sender]);
    require(tree[msg.sender].top == address(0));   // only top delegate can vote
    vote[_voteID] += tree[msg.sender].votePower;
  }

  function delegateTo(address _user)
  external
  returns (bool){
    require(auth[msg.sender]);
    require(auth[_user]);
    DelegateTree storage treeToJoin = tree[_user];
    DelegateTree storage senderTree = tree[msg.sender];
    // If this runs out of gas, call removeDelegate in it's own transaction
    if (senderTree.top != address(0)){
      removeDelegate(senderTree.top, msg.sender);
    }
    senderTree.top = _user;
    treeToJoin.down.push(msg.sender);
    treeToJoin.votePower += senderTree.votePower;
    return true;
  }

  // @notice removes _delegator from the
  // @dev moves up trees removing 1 vote power
  function removeDelegate(address _top, address _delegator)
  internal
  returns (bool) {
    DelegateTree storage oldDelegate = tree[_top];
    uint numDelegators = oldDelegate.down.length;
    _top = oldDelegate.top;
    for (uint16 i =0; i < numDelegators; i++){
      if (oldDelegate.down[i] == _delegator) {
        oldDelegate.down[i] = oldDelegate.down[numDelegators - 1];
        oldDelegate.down.length--;
        oldDelegate.votePower--;
        break;
      }
    }
    while (_top != address(0)) {
      tree[_top].votePower--;
      _top = tree[_top].top;
    }
    return true;
  }

  // TODO: move down tree and delete tree[delegator].top
  function removeDelegators(address _top)
  internal
  returns (bool) {
    return true;
  }

  function onboard(address _user)
  external
  returns (bool){
    require(_user != address(0));
    require(!auth[_user]);
    require(auth[msg.sender]);
    auth[_user] = true;
    DelegateTree storage newTree = tree[_user];
    newTree.votePower = 1;
    numUsers++;
  }

  // Not mandatory to have this...can add event in vote function
  function initiateRemoval(address _user)
  external {
    require(auth[msg.sender]);
    bytes32 voteID = keccak256(abi.encodePacked("remove", _user));
    emit logVoteToRemove(voteID, _user);
  }

  function executeRemoval(address _user)
  external
  returns (bool){
    require(auth[_user]);
    bytes32 voteID = keccak256(abi.encodePacked("remove", _user));
    require(vote[voteID].mul(100).div(numUsers) > threshold);
    if (tree[_user].top != address(0)){
      removeDelegate(tree[_user].top, _user);
    }
    // TODO: removeDelegators function
    delete tree[_user];
    delete auth[_user];
    delete vote[voteID];
    return true;
  }

  //Pass address(0) if you want to send ether, or the token contract address if you want to send ERC20
  // Not mandatory...can add event in vote function
  function initiateTransfer(address _account, uint _amount, address _token)
  external {
    require(auth[msg.sender]);
    bytes32 voteID = keccak256(abi.encodePacked("transfer", _account, _amount, _token));
    emit logVoteToTransfer(voteID, _account, _amount, _token);
  }

  function executeTransfer(address _account, uint _amount, address _token)
  external
  returns (bool){
    require(_account != address(0));
    bytes32 voteID = keccak256(abi.encodePacked("transfer", _account, _amount, _token));
    require(vote[voteID].mul(100).div(numUsers) > threshold);
    delete vote[voteID];
    if(_token == address(0)){
      //If address = 0, transfer ethereum
      _account.transfer(_amount);
    } else {
      ERC20(_token).transfer(_account, _amount);
    }
  }


  event logVoteCount(bytes32 voteID, uint count);
  event logVoteToRemove(bytes32 voteID, address user);
  event logVoteToTransfer(bytes32 voteID, address account, uint amount, address token);

}
