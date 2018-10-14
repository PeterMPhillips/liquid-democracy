# Liquid Democracy
A contract that handles delegation of votes using a liquid democracy model

## Description
Liquid democracy is a fusion between direct democracy and representative democracy where votes can directly vote on issues or delegate their vote to any other user.

For further reading check out:
  - [Dominik Schiener on Medium](https://medium.com/organizer-sandbox/liquid-democracy-true-democracy-for-the-21st-century-7c66f5e53b6f)
  

## Features
  - This contract allows a user to delegate their vote to any other user. 
  - To initiate a function the total votes for that function must be above the threshold that is set by the contructor.
  - Each function call creates a unique voteID, which can be voted on by the users.
  - If the vote passes the threshold, anyone can execute the function.
  - There is no time limit on the votes. This can easily be changed but I don't see a compelling reason to do so.
  
## Issues
  ### Recursion
  - One of the main problems with liquid democracy on Ethereum is the use of recursion.
  - Recursively iterating over every user and their tree of delegators when calculating the vote tally quickly gets an out of gas error. However, we can more easily keep a record of the current top delegates and the number of votes they control. This is accomplished by updating the list every time someone changes their delegate. The contract calculates how many votes the user controls, removes them from their current top delegate, and adds them to their new top delegate.
  - The contract also prevents an infinite loop of delegates by checking that all the higher level delegates are never the user doing the delegating.
   ### Loops
   - There is a limit to the total number of users that can use this contract. When calculating whether a vote succeeds, we have to loop through the userVotes list.
   - If that list is large, we get an out of gas error. The contract currently works with 200 members. I'm unsure what the physical limit is.
   - Potentially, you could rewrite the contract to only loop through top delegates votes. There is some extra overhead in constantly calculating who needs to be added and removed from the list. And it wouldn't help in the scenario where no one delgates their votes.
    
 ## Things to Add
  - One could make it so you can delegate to different users for different issues. You would just need different contracts that contains functions related to budget or investing, one for handling the administration, or for anything else within the power of the DAO.
