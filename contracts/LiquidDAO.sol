pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./ERC20.sol";

contract LiquidDAO{
  using SafeMath for uint256;

  uint threshold;
  address[] private users;
  mapping(address => address) private delegate; //For a given address, who do they delgate to
  mapping(address => address[]) private delegators; //For a given address, who delegates to them
  mapping(address => uint) private userVotes; //How many votes a user controls
  mapping(bytes32 => mapping(address => bool)) private vote; //A mapping of voting issues and who has voted for them
  mapping(bytes32 => bool) private successful; //A mapping of which votes have crossed the threshold and can be executed
  mapping(address => bool) private auth; //A mapping of who is authorized in the organization

  constructor(uint _threshold) public {
    threshold = _threshold;
    auth[msg.sender] = true;
    users.push(msg.sender);
    userVotes[msg.sender] = 1;
  }

  function voteFor(bytes32 _voteID)
  external {
    require(auth[msg.sender]);
    delegate[msg.sender] = address(0);
    vote[_voteID][msg.sender] = true;
  }

  function delegateTo(address _user)
  external
  returns (bool){
    require(auth[msg.sender]);
    require(auth[_user]);
    address topDelegate = checkDelegate(msg.sender, _user);
    uint votes = removeCurrentDelegateVotes(msg.sender);
    userVotes[topDelegate] += votes;
    delegate[msg.sender] = _user;
    delegators[_user].push(msg.sender);
    return true;
  }

  function checkDelegate(address _user, address _delegate)
  private
  returns (address) {
    require(_user != _delegate, 'Uh-oh, we got an infinite loop!');
    address topDelegate;
    if(delegate[_delegate] == address(0)){
      topDelegate = _delegate;
    } else {
      topDelegate = checkDelegate(_user, delegate[_delegate]);
    }
    return topDelegate;
  }

  function removeCurrentDelegateVotes(address _user)
  private
  returns(uint){
    address currentDelegate = getTopDelegate(_user);
    uint currentVotesControlled = getCurrentVoteControl(_user);
    userVotes[currentDelegate] -= currentVotesControlled;
    return currentVotesControlled;
  }

  function getTopDelegate(address _user)
  private
  returns(address){
    address topDelegate;
    if(delegate[_user] == address(0)){
      topDelegate = _user;
    } else {
      topDelegate = getTopDelegate(delegate[_user]);
    }
    return topDelegate;
  }

  function getCurrentVoteControl(address _user)
  private
  returns(uint){
    uint voteCount = 1;
    for(uint8 i=0; i<delegators[_user].length; i++){
      if(delegators[delegators[_user][i]].length == 0){
        voteCount += 1;
      } else {
        voteCount += getCurrentVoteControl(delegators[_user][i]);
      }
    }
    return voteCount;
  }

  function onboard(address _user)
  external
  returns (bool){
    require(_user != address(0));
    require(!auth[_user]);
    require(auth[msg.sender]);
    auth[_user] = true;
    users.push(_user);
    userVotes[_user] = 1;
  }

  function initiateRemoval(address _user)
  external {
    require(auth[msg.sender]);
    bytes32 voteID = keccak256(abi.encodePacked("remove", _user));
    emit logVoteToRemove(voteID, _user);
  }

  function executeRemoval(address _user)
  external
  returns (bool){
    ///*******************************///
    ///!!MUST ADJUST DELEGATE VOTES!!!///
    ///*******************************///
    bytes32 voteID = keccak256(abi.encodePacked("remove", _user));
    require(successful[voteID]);
    successful[voteID] = false;
    for(uint8 i=0; i<users.length; i++){
      delete vote[voteID][users[i]];
      if(users[i] == _user){
        auth[users[i]] = false;
        users[i] = users[users.length-1];
        delete users[users.length-1];
        users.length--;
      }
    }
    return true;
  }

  //Pass address(0) if you want to send ether, or the token contract address if you want to send ERC20
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
    require(successful[voteID]);
    delete successful[voteID];
    for(uint8 i=0; i<users.length; i++){
      delete vote[voteID][users[i]];
    }
    if(_account == address(0)){
      //If address = 0, transfer ethereum
      _account.transfer(_amount);
    } else {
      ERC20(_token).transfer(_account, _amount);
    }
  }

  function getDelegate(address _user)
  external
  view
  returns(address){
    return delegate[_user];
  }

  function getDelegators(address _user)
  external
  view
  returns(address[]){
    return delegators[_user];
  }

  function getVotes(address _user)
  external
  view
  returns(uint){
    return userVotes[_user];
  }

  function getTotalUsers()
  external
  view
  returns(uint){
    return users.length;
  }

  function getFraction()
  external
  view
  returns(uint){
    return users.length.getFractionalAmount(threshold);
  }
/***TALLY VOTES****************************************************/
  function queryVotes(bytes32 _voteID)
  external{
    uint voteCount = 0;
    uint fraction = uint256(users.length).getFractionalAmount(threshold);
    for(uint8 i=0; i<users.length; i++){
      uint votes = userVotes[users[i]];
      if(vote[_voteID][users[i]]){
        voteCount += votes;
      }
    }
    emit logVoteCount(_voteID, voteCount);
    if(voteCount > fraction){
      successful[_voteID] = true;
    }
  }

/* Get out of gas even in small groups
  function queryVotes(bytes32 _voteID)
  external
  returns (bool){
    uint voteCount = tallyVotesRecursive(_voteID, users);
    uint fraction = uint256(users.length).getFractionalAmount(threshold);
    if(voteCount >= fraction){
      successful[_voteID] = true;
      return true;
    } else {
      return false;
    }
  }

  function tallyVotesRecursive(bytes32 _voteID, address[] _votersToTally)
  private
  returns (uint){
    require(_votersToTally.length <= 50);
    address[] delegates;
    uint voteCount = 0;
    for(uint8 i=0; i<_votersToTally.length; i++){
      //Add direct votes
      if(delegate[_votersToTally[i]] == address(0)){
        if(vote[_voteID][_votersToTally[i]]){
          voteCount++;
        }
      } else {
        delegates[delegates.length] = delegate[_votersToTally[i]];
      }
    }
    if(delegates.length > 0){
      voteCount += tallyVotesRecursive(_voteID, delegates);
    }
    return voteCount;
  }
*/

  event logVoteCount(bytes32 voteID, uint count);
  event logVoteToRemove(bytes32 voteID, address user);
  event logVoteToTransfer(bytes32 voteID, address account, uint amount, address token);

}
