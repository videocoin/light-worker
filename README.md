# light-worker smart contracts

Vivid Labs Light Worker Smart Contracts.

Light Worker is a Decentralized Oracle framework that predicts the VID Price. The implementation is generic such that the framework can be used to predict vaule of any item of interest.

The framework consists of group of smartcontracts that operates as a Decentralized Autonomous Organizaion(DAO). Light Workers(Prediction Nodes) feed data to the DAO contracts on Vivid Blockchain.

Light Worker DAO Consists of three contracts running on VID blockchain:

## Token Gating Contract

The light-worker should obtain a token from the gating contract to participate in the VID price prediction. The light-worker submits a payment(stake) and acquires a token. The funds will stay in escrow/DAO contract described below. The light-worker can release the token (unstake) to reclaim his escrowed funds.

Token Gating contract is implemented extending ERC1155 token standard. A unique token id can be allocated

## Light Worker DAO contract

The DAO contract implements the logic for (1) describing the price prediction algorithm, (2) receiving proposals from the light-workers, (3) calculate the median value of proposals and (2) distributing the rewards.

## Reward Distribution contract

A utility contract that processes the reward distribution.

## Operation

- Ligt-Worker Registration: Light Workers(Prediciton Nodes) stake the required amount and gets eligibity to participate.

- Price Predcition Topic Creation: An oprator creates an item for predection(VID Price) and configures the parameters that includes

  - Reporting Period
  - Reward Amount
  - Staking Amount
  - Bounds for the predicted value
  - A threshold for deviation from median value to select winners.

- Price Proposal Reporting: Light Wokers poll the DAO contract for price prediction parameters i.e. start time, validity window etc and report the prediction to the DAO contracts.
- Rewarding: DAO contracts on a periodic external trigger from Operator Service, calculates the median of reported prices and rewards the Light Workers that reported price closer to the median price within a threshold.

## Testing

### yarn install

Install and update dependencies

### npx hardhat test

Start running test cases
