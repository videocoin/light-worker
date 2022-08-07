# light-worker
Vivid Labs Light Worker for Mobile and Web Apps

Light Worker is a Decentralized Oracle that performs predicts the VID Price. The implementation is generic such that the framework can be used to predict vaule of any item of interest.

The framework consists of group of smartcontracts that operates as a Decentralized Autonomous Organizaion(DAO). Light Workers(Prediction Nodes) feed data to the DAO contracts on Vivid Blockchain. 

Light Worker DAO Operation phases:

* Creation: An oprator creates an item for predection(VID Price) and configures the parameters that includes
    * Reporting Period
    * Reward Amount
    * Staking Amount
* Register: Light Worker(Prediciton Nodes) register with the DAO contracts and submits the required stake. 

* Reporting: Light Wokers report the item value(VID Price) to the DAO contracts.
* Rewarding: DAO contracts on a periodic external trigger, calculates the median of reported prices and rewards the Light Workers that reported price closer to the median price within a threshold.
