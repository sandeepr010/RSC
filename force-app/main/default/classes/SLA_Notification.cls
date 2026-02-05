/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : SLA_Notification
 * Author          : Sandeep.R
 * Created Date    : Jan 15, 2026
 * Last Modified By: Sandeep.R
 * Last Modified On: Jan 15, 2026
 * Description     : Batch class which will send notification to the users based on the SLA
 *
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 15, 2026  │ Sandeep.R    │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public class SLA_Notification implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        DateTime currentTime = System.now();
        DateTime plusOneHour = currentTime.addHours(1);
        
        return Database.getQueryLocator([SELECT Id, Priority__c, SLA_Count__c, RSC_Complaint__c, Next_Notification_On__c, RSC_Complaint__r.Name, 
        RSC_Complaint__r.Assigned_To__c, RSC_Complaint__r.Approved_By__c, RSC_Complaint__r.OwnerId, Completed_By__c, SLA_Status__c FROM RSC_SLA__c 
        WHERE Closed__c = false]); //AND Next_Notification_On__c > :currentTime AND Next_Notification_On__c < :plusOneHour]);
    }
    
    public void execute(Database.BatchableContext bc, List<RSC_SLA__c> scope){
        List<RSC_SLA__c> rscToUpdate = new List<RSC_SLA__c>();
        List<RSC_Complaint__c> rscComplaintToUpdate = new List<RSC_Complaint__c>();
        
        Map<Id,List<DataWrapper>> userRecordDetailsOne = new Map<Id,List<DataWrapper>>();
        Map<Id,List<DataWrapper>> userRecordDetailsTwo = new Map<Id,List<DataWrapper>>();
        Map<Id,List<DataWrapper>> userRecordDetailsEscalated = new Map<Id,List<DataWrapper>>();
        
        set<id> queueIds = new set<id>();
        
        for(RSC_SLA__c sla : scope){
            DataWrapper dataDetails = assigneValue(sla);
            Datetime nextNotificationTime = getNextNotifiTime(sla.Next_Notification_On__c, sla.Priority__c, sla.SLA_Count__c);
            if (String.valueOf(sla.RSC_Complaint__r.OwnerId).startsWith('00G')) {
                queueIds.add(sla.RSC_Complaint__r.OwnerId);
            }
            
            if(sla.SLA_Count__c == 1){
                sla.SLA_Count__c = 2;
                
                List<DataWrapper> recordIds = userRecordDetailsOne.containsKey(sla.RSC_Complaint__r.OwnerId) ? userRecordDetailsOne.get(sla.RSC_Complaint__r.OwnerId) : new List<DataWrapper>();
                recordIds.add(dataDetails);
                userRecordDetailsOne.put(sla.RSC_Complaint__r.OwnerId, recordIds);
            } else if(sla.SLA_Count__c == 2){
                sla.SLA_Count__c = 3;
                sla.SLA_Status__c = 'Warning';
                dataDetails.status = 'Warning';
                
                List<DataWrapper> recordIds = userRecordDetailsTwo.containsKey(sla.RSC_Complaint__r.OwnerId) ? userRecordDetailsTwo.get(sla.RSC_Complaint__r.OwnerId) : new List<DataWrapper>();
                recordIds.add(dataDetails);
                userRecordDetailsTwo.put(sla.RSC_Complaint__r.OwnerId, recordIds);
                
                List<DataWrapper> managerRecordIds = userRecordDetailsTwo.containsKey(sla.RSC_Complaint__r.Approved_By__c) ? userRecordDetailsTwo.get(sla.RSC_Complaint__r.Approved_By__c) : new List<DataWrapper>();
                managerRecordIds.add(dataDetails);
                userRecordDetailsTwo.put(sla.RSC_Complaint__r.Approved_By__c, managerRecordIds);
            } else {
                sla.SLA_Count__c = 4;
                sla.SLA_Status__c = 'Breached';
                dataDetails.status = 'Breached';
                
                // List<Id> recordIds = userRecordDetailsEscalated.containsKey(sla.OwnerId) ? userRecordDetailsEscalated.get(sla.OwnerId) : new List<Id>();
                // recordIds.add(sla.Id);
                // userRecordDetailsEscalated.put(sla.OwnerId, recordIds);
                
                List<DataWrapper> managerRecordIds = userRecordDetailsEscalated.containsKey(sla.RSC_Complaint__r.Approved_By__c) ? userRecordDetailsEscalated.get(sla.RSC_Complaint__r.Approved_By__c) : new List<DataWrapper>();
                managerRecordIds.add(dataDetails);
                userRecordDetailsEscalated.put(sla.RSC_Complaint__r.Approved_By__c, managerRecordIds);
                
                RSC_Complaint__c rscComplaint = new RSC_Complaint__c(Id = sla.RSC_Complaint__c);
                rscComplaint.Assigned_To__c = sla.RSC_Complaint__r.Approved_By__c;
                rscComplaintToUpdate.add(rscComplaint);
            }
            sla.Next_Notification_On__c = nextNotificationTime;
            rscToUpdate.add(sla);
        }
        
        Map<Id, List<Id>> queueUserMap = getQueueUsers(queueIds);
        OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
        
        sendFirstNotification(userRecordDetailsOne, queueUserMap, owea.Id);
        sendSecondNotification(userRecordDetailsTwo, queueUserMap, owea.Id);
        sendUrgentNotification(userRecordDetailsEscalated, queueUserMap, owea.Id);
        
        update rscToUpdate;
        if(!rscComplaintToUpdate.isEmpty()){
            update rscComplaintToUpdate;
        }
    }
    
    public void finish(Database.BatchableContext bc){
        System.debug('Na an');
    }
    
    private static Datetime getNextNotifiTime(Datetime curTime, String type, Decimal count){
        if(count == 1){
            curTime = type == 'urgent' ? curTime.addHours(5) : curTime.addHours(10);
        } else if(count == 2) {
            curTime = type == 'urgent' ? curTime : curTime.addHours(4);
        }
        
        return curTime;
    }
    
    private static Map<Id, List<Id>> getQueueUsers(Set<Id> queueId) {
        if(queueId.isEmpty()){
            return new Map<Id, List<Id>>();
        }
        Map<Id, List<Id>> queueUserMap = new Map<Id, List<Id>>();
        for(GroupMember gm : [SELECT Id, UserOrGroupId, GroupId FROM GroupMember WHERE GroupId IN:queueId WITH SECURITY_ENFORCED]){
            if(queueUserMap.containsKey(gm.GroupId)){
                queueUserMap.get(gm.GroupId).add(gm.UserOrGroupId);
            } else {
                queueUserMap.put(gm.GroupId, new List<Id>{gm.UserOrGroupId});
            }
        }
        return queueUserMap;
    }
    
    private static void sendFirstNotification(Map<Id,List<DataWrapper>> userRecordDetails, Map<Id, List<Id>> queueDetails, Id owea){
        if(userRecordDetails.isEmpty()){
            return;
        }
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for(Id userQueue : userRecordDetails.keySet()){
            if(queueDetails.containsKey(userQueue)){
                String emailBody = buildEmailBody(userRecordDetails.get(userQueue), 'first', baseUrl);
                for(Id userId : queueDetails.get(userQueue)){
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTargetObjectId(userId);
                    mail.setSaveAsActivity(false);
                    mail.setSubject('Reminder for RSC Complaint SLA');
                    mail.setHtmlBody(emailBody);
                    mail.setOrgWideEmailAddressId(owea);
                    mail.setTreatTargetObjectAsRecipient(true);
                    emails.add(mail);
                }
            } else {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(userQueue);
                mail.setSaveAsActivity(false);
                mail.setSubject('Reminder for RSC Complaint SLA');
                mail.setHtmlBody(buildEmailBody(userRecordDetails.get(userQueue), 'first', baseUrl));
                mail.setOrgWideEmailAddressId(owea);
                mail.setTreatTargetObjectAsRecipient(true);
                emails.add(mail);
            }
        }
        Messaging.sendEmail(emails);
    }
    
    private static void sendSecondNotification(Map<Id,List<DataWrapper>> userRecordDetails, Map<Id, List<Id>> queueDetails, Id owea){
        if(userRecordDetails.isEmpty()){
            return;
        }
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for(Id userQueue : userRecordDetails.keySet()){
            if(queueDetails.containsKey(userQueue)){
                String emailBody = buildEmailBody(userRecordDetails.get(userQueue), 'second', baseUrl);
                for(Id userId : queueDetails.get(userQueue)){
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTargetObjectId(userId);
                    mail.setSaveAsActivity(false);
                    mail.setSubject('Reminder for RSC Complaint SLA about to breach');
                    mail.setHtmlBody(emailBody);
                    mail.setOrgWideEmailAddressId(owea);
                    mail.setTreatTargetObjectAsRecipient(true);
                    emails.add(mail);
                }
            } else {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(userQueue);
                mail.setSaveAsActivity(false);
                mail.setSubject('Reminder for RSC Complaint SLA about to breach');
                mail.setHtmlBody(buildEmailBody(userRecordDetails.get(userQueue), 'second', baseUrl));
                mail.setOrgWideEmailAddressId(owea);
                mail.setTreatTargetObjectAsRecipient(true);
                emails.add(mail);
            }
        }
        Messaging.sendEmail(emails);
    }
    
    private static void sendUrgentNotification(Map<Id,List<DataWrapper>> userRecordDetails, Map<Id, List<Id>> queueDetails, Id owea){
        if(userRecordDetails.isEmpty()){
            return;
        }
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for(Id userQueue : userRecordDetails.keySet()){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(userQueue);
            mail.setSaveAsActivity(false);
            mail.setSubject('Reminder for RSC Complaint SLA breatched');
            mail.setHtmlBody(buildEmailBody(userRecordDetails.get(userQueue), 'breached', baseUrl));
            mail.setOrgWideEmailAddressId(owea);
            mail.setTreatTargetObjectAsRecipient(true);
            emails.add(mail);
        }
        Messaging.sendEmail(emails);
    }
    
    public static String buildEmailBody(List<DataWrapper> dataList, String type, String baseUrl) {
        
        String emailBody = '';
        
        emailBody += '<html><body>';
        emailBody += '<p>Hello,</p>';
        if (type == 'first') {
            emailBody += 'Please check the following RSC Complaints for which SLA is not met:<br/>';
        } else if (type == 'second') {
            emailBody += 'Please check the following RSC Complaints for which SLA is about to breach:<br/>';
        } else {
            emailBody += '<b>SLA breached for the following RSC Complaints and Assigned to you:</b><br/>';
        }
        emailBody += '<p>Please find the details below:</p>';
        
        emailBody += '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;width:100%;">';
        emailBody += '<thead>';
        emailBody += '<tr style="background-color:#f2f2f2;">';
        emailBody += '<th>Name</th>';
        // emailBody += '<th>Record Link</th>';
        emailBody += '<th>Status</th>';
        emailBody += '<th>Target</th>';
        emailBody += '</tr>';
        emailBody += '</thead>';
        emailBody += '<tbody>';
        
        for (DataWrapper dw : dataList) {
            emailBody += '<tr>';
            
            // Name
            // emailBody += '<td>' + dw.recordName + '</td>';
            
            // Record Link
            emailBody += '<td>';
            emailBody += '<a href="' + baseUrl + '/' + dw.recordId + '">';
            emailBody += dw.recordName;
            emailBody += '</a>';
            emailBody += '</td>';
            
            // Status
            emailBody += '<td>' + String.valueOf(dw.status) + '</td>';
            
            // Target DateTime
            emailBody += '<td>' + dw.targetDateTime + '</td>';
            
            emailBody += '</tr>';
        }
        
        emailBody += '</tbody>';
        emailBody += '</table>';
        
        emailBody += '<br/><p>Regards,<br/>Support Team</p>';
        emailBody += '</body></html>';
        
        return emailBody;
    }
    
    
    private static DataWrapper assigneValue(RSC_SLA__c slaRecord){
        DataWrapper response = new DataWrapper();
        response.recordId = slaRecord.RSC_Complaint__c;
        response.recordName = slaRecord.RSC_Complaint__r.Name;
        response.targetDateTime = slaRecord.Completed_By__c.format('dd/MM/yyyy HH:mm');
        response.status = slaRecord.SLA_Status__c;
        return response;
    }
    
    private class DataWrapper{
        private Id recordId;
        private String recordName;
        private String targetDateTime;
        private String status;
    }
    
}