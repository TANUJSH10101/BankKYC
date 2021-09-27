pragma solidity ^0.8.4
// KYC Flow will modified to acchieve same functionality but to save the gas on performing the functionalities
contract KYC {
    // data decleration
    // customer structure
    struct customer {
        bytes32 userName;               //stores userName of the customer -unique
        string customerData;            // stores userData of the customer
        address bank;                   // stores in which bank user has its account
        bool KYCDone;                   // stores is KYCDone done for the customer or not
        uint256 upVote;                 // stores the count of upVote for a customer
        mapping (address => address) upVoteList; // stores all the names of bank upvoted
        uint256 downVote;               // stores the count of downVote for a customer
        mapping (address => address) downVoteList; // stores all the names of bank downvoted
        bool verifiedCustomer;          // once the number of upVote is more than a threshhold we are setting verified Customer flag as true
        bool blackListedCustomer;       // once the number of downVote is more than a threshhold we are setting blackListedCustomer flag as true
        address createdBy;              // this stores who created the customer entry in the customer list
        address lastUpdatedBy;          // this stores who modified or changed anything in the entry last time
    }
    //bank structure
    struct bank {
        string name;
        address ethAddress;
        uint256 complaintsReported;
        mapping (address => address) complaintsDetail; // stored who all reported the bank to control duplicate complaints
        uint256 KYCCount;
        string regNumber;
        bool isAllowedToVote;
    }
    //kyc list structure
    struct kycList {
        bytes32 customerName;
        address bank;
        string customerData;
        // string customerData;
    }
    // variables
    address private adminAddress;
    uint256 private bankCount = 0;
    //create mapping for bank and customer
    mapping (bytes32 => customer) customerData;
    mapping (address => bank) bankData;
    mapping (bytes32 => kycList) KYCList;
    // declaring modifier
    // Check whether the requestor is admin or not
    modifier isAdmin {
        require(adminAddress == msg.sender,"Only admin is allowed to operate this functionality");
        _;
    }
    // Check whether bank has been validated and added by admin
    modifier isBankValid {
        require(bankData[msg.sender].ethAddress == msg.sender, "Unauthenticated requestor! Bank not been added by admin.");
        _;
    }
    // Check whether bank are allowed to Vote ot not
    modifier isBankAllowed{
        require(bankData[msg.sender].isAllowedToVote == true, "You are not authorised to Vote the customer");
        _;
    }
    // declaring events
    event bankAdded (string, address, address, string);
    event KYCInitiated(bytes32, address);
    event KYCInProcess(bytes32, address);
    event customerAdded(bytes32);
    event customerDeleted(bytes32,address);
    event bankDeleted(address, address);
    
    // constructor
    // defining the msg.sender as the Admin of the Application
    constructor () {
        adminAddress = msg.sender;
    }
    // function defination and implementation
    
    // Function 1. initiateCustomerKYCRequest will help you to generate the KYC request for the customer after that it will be proceed for the KYC Verification process
    // Before adding a new KYC request, we are checking that the KYC of the same customer is already done or not.
    // And if not then is the customer already under KYC process or not.
    function initiateCustomerKYCRequest(bytes32 customerName, string memory _customerDataHash) private{
        emit KYCInitiated(customerName,msg.sender);
        require(customerData[customerName].KYCDone == false, "Customer Already Present in the system");
        require(KYCList[customerName].customerName != customerName, "Your KYC process is still in progress");
        KYCList[customerName].customerName = customerName;
        KYCList[customerName].bank = msg.sender;
        KYCList[customerName].customerData = _customerDataHash;
    }
    // Function 2. addCustomerData will help you to add the customer details to the Customer List and validate the customer data with the flow.
    // This method is getting called by banks only, they will pick up the kyc process from KYC list and process further
    // If customer is already present in the customer List or the customer's KYC process is still pending, return respective message else process further
    function addCustomerData(bytes32 userName, string memory userDatafromStorage, address bankAddress) private isBankValid returns (string memory){
        emit customerAdded(userName);
        if ( customerData[userName].userName == userName){
            if( customerData[userName].KYCDone == true ){
                return "Customer Already Exist in the System.";
            }else{
                return "KYC is still pending, wait for some more time.";
            }
        }else{
            // create new customer and initiate KYC
            customerData[userName].userName = userName;
            customerData[userName].customerData = userDatafromStorage;
            customerData[userName].bank = bankAddress;
            customerData[userName].KYCDone = true;
            customerData[userName].upVote = 0;
            customerData[userName].downVote = 0;
            customerData[userName].verifiedCustomer = false;
            customerData[userName].createdBy = msg.sender;
            customerData[userName].lastUpdatedBy = msg.sender;
            return "Customer Data Added & KYC Process Initiated.";
        }
    }
    // Function 3. modifyCustomerData will allow you to modify the alaready added customer Data and set KYC done to false,
    // As any modification in original data will may create any type of anamoly thats why we are initiating the KYC request again
    function modifyCustomerData(bytes32 userName, string memory _customerData, address _bank) public{
        require( customerData[userName].bank != address(0) );
        customerData[userName].customerData = _customerData;
        customerData[userName].bank = _bank;
        customerData[userName].KYCDone = false;
        customerData[userName].lastUpdatedBy = msg.sender;
        initiateCustomerKYCRequest(userName, _customerData); 
    }
    // Function 4. updateCustomerDataafterKYC will trigger after bank do the complete KYC process for a customer
    // They will call addCustomerData to create the customer in the customer List and delete the customer from KYCList
    // This process can only be done by the banks, and also bank will make sure to verify all the required documents for the customer
    function updateCustomerDataafterKYC(bytes32 userName) public isBankValid {
        emit KYCInProcess(userName, msg.sender);
        addCustomerData(userName, KYCList[userName].customerData, msg.sender);
        customerData[userName].KYCDone = true;
        customerData[userName].upVote = 0;
        customerData[userName].downVote = 0;
        customerData[userName].verifiedCustomer = false;
        customerData[userName].blackListedCustomer = false;
        customerData[userName].lastUpdatedBy = msg.sender;
        bankData[msg.sender].KYCCount = bankData[msg.sender].KYCCount + 1;
        delete KYCList[userName];
    }
    // Function 5. getCustomerData will help you fetch all the customer details stored in the customer List
    function getCustomerData(bytes32 customerName) public view  returns (string memory, address, bool, uint256, uint256, bool, address){
        return (customerData[customerName].customerData, customerData[customerName].bank, customerData[customerName].KYCDone, customerData[customerName].upVote, customerData[customerName].downVote, customerData[customerName].verifiedCustomer, customerData[customerName].createdBy);
     }
    // Function 6. deleteCustomerData will only be accessible by a bank and it allows banks to delete the customer details from the customer List
    function deleteCustomerData(bytes32 customerName) public isBankValid {
        emit customerDeleted(customerName, msg.sender);
        delete customerData[customerName];
    }
    // Function 7. upVoteCustomer will allow, allowed banks to give positive points to the banks through upVoting them
    // A bank are not allowed to upvote more than once
    function upVoteCustomer(bytes32 customerName) public isBankValid isBankAllowed {
        require(customerData[customerName].upVoteList[msg.sender] != msg.sender, "Already UpVoted the customer");
        customerData[customerName].upVote = customerData[customerName].upVote + 1;
        customerData[customerName].upVoteList[msg.sender] = msg.sender;
        if (customerData[customerName].upVote >= 33){
            customerData[customerName].verifiedCustomer = true;
        }
    }
    // Function 7. downVoteCustomer will allow, allowed banks to give positive points to the banks through downVoting them
    // A bank are not allowed to downvote more than once
    function downVoteCustomer(bytes32 customerName) public isBankValid isBankAllowed {
        require(customerData[customerName].downVoteList[msg.sender] != msg.sender, "Already DownVoted the customer");
        customerData[customerName].downVote = customerData[customerName].downVote + 1;
        customerData[customerName].downVoteList[msg.sender] = msg.sender;
        if (customerData[customerName].downVote >= 33){
            customerData[customerName].blackListedCustomer = true;
            customerData[customerName].KYCDone = false;
            initiateCustomerKYCRequest(customerName,customerData[customerName].customerData);
        }
    }
    //Function 8. Through this function allowed banks can report other bank for security and authenticity
    // Once the complaintsReported crosses a threshold of 1000 complaints then the respective bank will not be allowed to Vote
    function reportBank(address _bank) public isBankValid{
        require(bankData[_bank].complaintsDetail[_bank] != _bank, "You already reported the bank"); // no bank is allowed to report a bank twice
        bankData[_bank].complaintsReported = bankData[_bank].complaintsReported + 1;
        if (calculateMajority(bankData[_bank].complaintsReported) == true){
            bankData[_bank].isAllowedToVote = false;
        }
    }
    
    //Function 9. addBankData will allow admin to add the bank details to the bank list data
    function addBankData(string memory bankName, string memory regNumber, address bankAddress, bool _isAllowedToVote) public isAdmin {
        emit bankAdded(bankName, bankAddress, msg.sender, regNumber);
        bankData[bankAddress].name = bankName;
        bankData[bankAddress].regNumber = regNumber;
        bankData[bankAddress].ethAddress = bankAddress;
        bankData[bankAddress].complaintsReported = 0;
        bankData[bankAddress].KYCCount = 0;
        bankData[bankAddress].isAllowedToVote = _isAllowedToVote;
        bankCount++;
    }
    //Function 10. based on what data need to be modified, admins can update the respective bank details mentioned
    function updateBankData(address bankAddress, bool updateBankName, string memory bankName, bool updateRegNumber, string memory regNumber) public isAdmin{
        require(bankData[bankAddress].ethAddress == bankAddress, "Bank is not available in the bank list");
        if(updateBankName == true){
            bankData[bankAddress].name = bankName;
        }
        if(updateRegNumber == true){
            bankData[bankAddress].regNumber = regNumber;
        }
    }
    //Function 11. This function allows admin to delete Bank data from bank List
    function deleteBankData(address bankAddress) public isAdmin{
        emit bankDeleted(bankAddress,msg.sender);
        delete bankData[bankAddress];
        bankCount--;
    }
    //Function 12. Calculate percent majority of Banks allowed bank defaulty or not
    function calculateMajority(uint256 count) private view returns (bool){
        uint256 majority = bankCount/3;
        if (count > majority){
            return true;
        }
        return false;
    }
}

;
