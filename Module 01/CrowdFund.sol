// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CrowdfundHub is Ownable, ReentrancyGuard, Pausable {
    // Enum for project states (CF-2)
    enum ProjectState { FUNDING, SUCCESS, FAIL }

    // Struct to store project details (CF-1, CF-9)
    struct Project {
        address owner; // Project creator
        string title; // Project title
        uint256 goal; // Funding goal in wei
        uint256 deadline; // Unix timestamp for deadline
        uint256 totalPledged; // Total ETH pledged
        ProjectState state; // Current state of the project
        bool withdrawn; // Tracks if owner has withdrawn funds (CF-5)
    }

    // Mapping to store all projects by ID
    mapping(uint256 => Project) public projects;
    // Mapping to track contributions per backer per project (CF-3, CF-6)
    mapping(uint256 => mapping(address => uint256)) public contributions;
    // Accumulated fees for the contract owner (CF-7)
    uint256 public totalFees;
    // Incremental project ID
    uint256 public nextProjectId;

    // Events for pledge and finalization (CF-3, CF-4)
    event PledgeReceived(address indexed backer, uint256 indexed projectId, uint256 amount);
    event ProjectFinalised(uint256 indexed projectId, ProjectState state);

    // Constructor sets the contract deployer as owner
    constructor() Ownable(msg.sender) {}

    // CF-1: Open a new project
    function openProject(string calldata _title, uint256 _goal, uint256 _deadline) 
        external 
        whenNotPaused 
        returns (uint256 projectId) 
    {
        require(_deadline > block.timestamp + 1 days, "Deadline must be at least 1 day from now");
        require(_goal > 0, "Goal must be greater than 0");

        projectId = nextProjectId++;
        projects[projectId] = Project({
            owner: msg.sender,
            title: _title,
            goal: _goal,
            deadline: _deadline,
            totalPledged: 0,
            state: ProjectState.FUNDING,
            withdrawn: false
        });

        return projectId;
    }

    // CF-3: Contribute ETH to a project
    function contribute(uint256 _projectId) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        Project storage project = projects[_projectId];
        require(project.owner != address(0), "Project does not exist");
        require(project.state == ProjectState.FUNDING, "Project not in FUNDING state");
        require(block.timestamp <= project.deadline, "Project deadline passed");
        require(msg.value > 0, "Contribution must be greater than 0");

        contributions[_projectId][msg.sender] += msg.value;
        project.totalPledged += msg.value;

        emit PledgeReceived(msg.sender, _projectId, msg.value);
    }

    // CF-4: Finalize a project after deadline
    function finalise(uint256 _projectId) 
        external 
        whenNotPaused 
    {
        Project storage project = projects[_projectId];
        require(project.owner != address(0), "Project does not exist");
        require(project.state == ProjectState.FUNDING, "Project already finalized");
        require(block.timestamp > project.deadline, "Deadline not yet reached");

        if (project.totalPledged >= project.goal) {
            project.state = ProjectState.SUCCESS;
            // CF-7: Calculate and store 2% fee
            uint256 fee = (project.totalPledged * 2) / 100;
            totalFees += fee;
            project.totalPledged -= fee; // Deduct fee from project funds
        } else {
            project.state = ProjectState.FAIL;
        }

        emit ProjectFinalised(_projectId, project.state);
    }

    // CF-5: Owner withdraws funds in SUCCESS state
    function withdraw(uint256 _projectId) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        Project storage project = projects[_projectId];
        require(project.owner != address(0), "Project does not exist");
        require(project.state == ProjectState.SUCCESS, "Project not in SUCCESS state");
        require(msg.sender == project.owner, "Only project owner can withdraw");
        require(!project.withdrawn, "Funds already withdrawn");

        project.withdrawn = true;
        uint256 amount = project.totalPledged;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    // CF-6: Backer claims refund in FAIL state
    function claimRefund(uint256 _projectId) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        Project storage project = projects[_projectId];
        require(project.owner != address(0), "Project does not exist");
        require(project.state == ProjectState.FAIL, "Project not in FAIL state");
        uint256 contribution = contributions[_projectId][msg.sender];
        require(contribution > 0, "No contribution to refund");

        contributions[_projectId][msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: contribution}("");
        require(success, "Refund failed");
    }

    // CF-7: Contract owner withdraws accumulated fees
    function withdrawFees() 
        external 
        onlyOwner 
        nonReentrant 
        whenNotPaused 
    {
        uint256 amount = totalFees;
        require(amount > 0, "No fees to withdraw");
        totalFees = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Fee withdrawal failed");
    }

    // CF-9: View function to get project details
    function getProject(uint256 _projectId) 
        external 
        view 
        returns (
            address owner,
            string memory title,
            uint256 goal,
            uint256 deadline,
            uint256 totalPledged,
            ProjectState state,
            bool withdrawn
        ) 
    {
        Project storage project = projects[_projectId];
        require(project.owner != address(0), "Project does not exist");
        return (
            project.owner,
            project.title,
            project.goal,
            project.deadline,
            project.totalPledged,
            project.state,
            project.withdrawn
        );
    }
}
