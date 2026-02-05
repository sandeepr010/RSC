@isTest
private class RSCComplaintTriggerHandlerTest {
    @TestSetup
    static void makeData(){
        List<RSC_Complaint_Category__c> categoryList = new List<RSC_Complaint_Category__c>();
        categoryList.add( new RSC_Complaint_Category__c(
            Category_Label__c = 'Category Urgent',
        Priotiy__c = 'Urgent'
            ));
        categoryList.add( new RSC_Complaint_Category__c(
            Category_Label__c = 'Category High',
        Priotiy__c = 'High'
            ));
        categoryList.add( new RSC_Complaint_Category__c(
            Category_Label__c = 'Category Medium',
        Priotiy__c = 'Medium'
            ));
        categoryList.add( new RSC_Complaint_Category__c(
            Category_Label__c = 'Category Normal',
        Priotiy__c = 'Normal'
            ));
        
        insert categoryList;
        
        List<RSC_Complaint__c> complaintList = new List<RSC_Complaint__c>();
        complaintList.add( new RSC_Complaint__c(
            Subject__c = 'Test Complaint Normal',
        RSC_Complaint_Category__c = categoryList[3].Id
            ));
        complaintList.add( new RSC_Complaint__c(
            Subject__c = 'Test Complaint Medium',
        RSC_Complaint_Category__c = categoryList[2].Id
            ));
        complaintList.add( new RSC_Complaint__c(
            Subject__c = 'Test Complaint High',
        RSC_Complaint_Category__c = categoryList[1].Id
            ));
        complaintList.add( new RSC_Complaint__c(
            Subject__c = 'Test Complaint Urgent',
        RSC_Complaint_Category__c = categoryList[0].Id
            ));
        
        // RSC_Complaint__c complaint = new RSC_Complaint__c(
        //     Subject__c = 'Test Complaint Assigne',
        // Assigned_To__c = agent.Id,
        // Approved_By__c = approver.Id,
        // OwnerId = q.Id
        //     );
        //complaintList.add(complaint);
        
        insert complaintList;
    }
    @isTest
    static void myUnitTest() {
        List<Id> complaintIds = new List<Id>();
        for(RSC_Complaint__c complaint : [SELECT Id FROM RSC_Complaint__c]){
            complaintIds.add(complaint.Id);
        }
        Test.startTest();
            RSCComplaintTriggerHandler.sendEmailWithAttachment(complaintIds);
        Test.stopTest();

        System.assert.areEqual(false, complaintIds.isEmpty());
    }
}