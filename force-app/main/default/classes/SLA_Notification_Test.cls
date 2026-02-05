/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : SLA_Notification_Test
 * Author          : Sandeep.R
 * Created Date    : Jan 15, 2026
 * Last Modified By: Sandeep.R
 * Last Modified On: Jan 15, 2026
 * Description     : Test class for SLA_Notification
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 15, 2026  │ Sandeep.R    │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@isTest
public class SLA_Notification_Test {
    @TestSetup
    static void makeData(){
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User approver = new User(
            Alias = 'apprv',
        Email = 'approver@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'Approver',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        Username = 'approver' + System.currentTimeMillis() + '@test.com'
            );
        
        User agent = new User(
            Alias = 'agent',
        Email = 'agent@test.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'Agent',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        Username = 'agent' + System.currentTimeMillis() + '@test.com'
            );
        
        insert new List<User>{ approver, agent };
        
        // Fetch Permission Set
        PermissionSet ps = [
    SELECT Id 
    FROM PermissionSet 
    WHERE Name = 'RSC_Manager_Permission' 
    LIMIT 1
];
        //User uId = [SELECT Id FROM User WHERE Id = :agent.Id LIMIT 1];
        
        // Assign Permission Set to Agent User
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = agent.Id,
        PermissionSetId = ps.Id
            );
        insert psa;
        
        List<Group> queueList = new List<Group>();
        
        // Create Queue
        Group qUrgent = new Group(
            Name = 'RSC_Urgent',
        Type = 'Queue'
            );
        queueList.add(qUrgent);
        
        Group qHigh = new Group(
            Name = 'RSC_High',
        Type = 'Queue'
            );
        queueList.add(qHigh);
        
        Group qMedium = new Group(
            Name = 'RSC_Medium',
        Type = 'Queue'
            );
        queueList.add(qMedium);
        
        Group qNormal = new Group(
            Name = 'RSC_Normal',
        Type = 'Queue'
            );
        queueList.add(qNormal);
        insert queueList;
        
        List<GroupMember> queueMemberList = new List<GroupMember>();
        // Add user to queue
        for(integer i=0; i < queueList.size(); i++){
            queueMemberList.add( new GroupMember(
                GroupId = queueList[i].Id,
            UserOrGroupId = agent.Id
                ));
        }
        insert queueMemberList;
        User UserInfo = [SELECT Id, Name, Username FROM User WHERE Id = :agent.id WITH SECURITY_ENFORCED];
        System.runAs(UserInfo)
        {
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
                Status__c = 'In Progress',
            RSC_Complaint_Category__c = categoryList[3].Id
                ));
            complaintList.add( new RSC_Complaint__c(
                Subject__c = 'Test Complaint Medium',
                Status__c = 'In Progress',
            RSC_Complaint_Category__c = categoryList[2].Id
                ));
            complaintList.add( new RSC_Complaint__c(
                Subject__c = 'Test Complaint High',
                Status__c = 'In Progress',
            RSC_Complaint_Category__c = categoryList[1].Id
                ));
            complaintList.add( new RSC_Complaint__c(
                Subject__c = 'Test Complaint Urgent',
                Status__c = 'In Progress',
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
        
    }
    
    @IsTest
    static void testFirst(){
        User UserInfoD = [SELECT Id FROM User WHERE Email = 'agent@test.com' LIMIT 1];
        System.runAs(UserInfoD)
        {
        List<RSC_Complaint__c> complaintDetails = [SELECT Id, Status__c, Priority__c, Is_Approved__c FROM RSC_Complaint__c];
        System.debug('complaintDetails'+complaintDetails);
        for(RSC_Complaint__c comp : complaintDetails){
            comp.Status__c = 'In Progress';
            comp.Is_Approved__c = true;
            comp.Approved_By__c = UserInfoD.Id;
            comp.Approval_Date__c = System.now();
        }
        update complaintDetails;
        System.debug('complaintDetails 173'+[SELECT Id, Status__c, Priority__c, Is_Approved__c FROM RSC_Complaint__c]);
        
        List<RSC_SLA__c> slaDetails = [SELECT Id, Priority__c FROM RSC_SLA__c];
        System.debug('slaDetails'+slaDetails);
        for(RSC_SLA__c sla : slaDetails){
            if(sla.Priority__c == 'Normal'){
                sla.SLA_Count__c = 2;
            } else if (sla.Priority__c == 'Medium'){
                sla.SLA_Count__c = 3;
            }
        }
        update slaDetails;
    }
        
        Test.startTest();
        SLA_Notification slaNotification = new SLA_Notification();
        Database.executeBatch(slaNotification, 100);
        Test.stopTest();
        List<RSC_Complaint__c> complaintDetails = [SELECT Id FROM RSC_Complaint__c WITH SECURITY_ENFORCED];
        System.Assert.areEqual(false, complaintDetails.isEmpty(), 'Complaint List is Not Empty');
    }
}