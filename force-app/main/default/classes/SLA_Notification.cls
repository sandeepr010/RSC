public class SLA_Notification implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        DateTime currentTime = System.now();
        DateTime plusOneHour = currentTime.addHours(1);

        return Database.getQueryLocator([SELECT Id, Priority__c, SLA_Count__c, RSC_Complaint__c, Next_Notification_On__c, 
        RSC_Complaint__r.Assigned_To__c, RSC_Complaint__r.Approved_By__c, RSC_Complaint__r.OwnerId FROM RSC_SLA__c 
        WHERE Closed__c = false ]);//AND Next_Notification_On__c > :currentTime AND Next_Notification_On__c < :plusOneHour
    }
    
    public void execute(Database.BatchableContext bc, List<RSC_SLA__c> scope){
        List<RSC_SLA__c> rscToUpdate = new List<RSC_SLA__c>();
        List<RSC_Complaint__c> rscComplaintToUpdate = new List<RSC_Complaint__c>();
        
        Map<Id,List<Id>> userRecordDetailsOne = new Map<Id,List<Id>>();
        Map<Id,List<Id>> userRecordDetailsTwo = new Map<Id,List<Id>>();
        Map<Id,List<Id>> userRecordDetailsEscalated = new Map<Id,List<Id>>();
        
        set<id> queueIds = new set<id>();
        
        for(RSC_SLA__c sla : scope){
            Datetime nextNotificationTime = getNextNotifiTime(sla.Next_Notification_On__c, sla.Priority__c, sla.SLA_Count__c);
            if (String.valueOf(sla.RSC_Complaint__r.OwnerId).startsWith('00G')) {
                queueIds.add(sla.RSC_Complaint__r.OwnerId);
            }
            
            if(sla.SLA_Count__c == 1){
                sla.SLA_Count__c = 2;
                
                List<Id> recordIds = userRecordDetailsOne.containsKey(sla.RSC_Complaint__r.OwnerId) ? userRecordDetailsOne.get(sla.RSC_Complaint__r.OwnerId) : new List<Id>();
                recordIds.add(sla.Id);
                userRecordDetailsOne.put(sla.RSC_Complaint__r.OwnerId, recordIds);
            } else if(sla.SLA_Count__c == 2){
                sla.SLA_Count__c = 3;
                
                List<Id> recordIds = userRecordDetailsTwo.containsKey(sla.RSC_Complaint__r.OwnerId) ? userRecordDetailsTwo.get(sla.RSC_Complaint__r.OwnerId) : new List<Id>();
                recordIds.add(sla.Id);
                userRecordDetailsTwo.put(sla.RSC_Complaint__r.OwnerId, recordIds);
                
                List<Id> managerRecordIds = userRecordDetailsTwo.containsKey(sla.RSC_Complaint__r.Approved_By__c) ? userRecordDetailsTwo.get(sla.RSC_Complaint__r.Approved_By__c) : new List<Id>();
                managerRecordIds.add(sla.Id);
                userRecordDetailsTwo.put(sla.RSC_Complaint__r.Approved_By__c, managerRecordIds);
            } else {
                sla.SLA_Count__c = 4;
                
                // List<Id> recordIds = userRecordDetailsEscalated.containsKey(sla.OwnerId) ? userRecordDetailsEscalated.get(sla.OwnerId) : new List<Id>();
                // recordIds.add(sla.Id);
                // userRecordDetailsEscalated.put(sla.OwnerId, recordIds);
                
                List<Id> managerRecordIds = userRecordDetailsEscalated.containsKey(sla.RSC_Complaint__r.Approved_By__c) ? userRecordDetailsEscalated.get(sla.RSC_Complaint__r.Approved_By__c) : new List<Id>();
                managerRecordIds.add(sla.Id);
                userRecordDetailsEscalated.put(sla.RSC_Complaint__r.Approved_By__c, managerRecordIds);

                RSC_Complaint__c rscComplaint = new RSC_Complaint__c(Id = sla.RSC_Complaint__c);
                rscComplaint.Assigned_To__c = sla.RSC_Complaint__r.Approved_By__c;
                rscComplaintToUpdate.add(rscComplaint);
            }
            sla.Next_Notification_On__c = nextNotificationTime;
            rscToUpdate.add(sla);
        }
        
        Map<Id, List<Id>> queueUserMap = getQueueUsers(queueIds);
        System.debug('userRecordDetailsOne: ' + queueUserMap);
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
    
    private static void sendFirstNotification(Map<Id,List<Id>> userRecordDetails, Map<Id, List<Id>> queueDetails, Id owea){
        if(userRecordDetails.isEmpty()){
            return;
        }
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for(Id userQueue : userRecordDetails.keySet()){
            if(queueDetails.containsKey(userQueue)){
                String emailBody = getBody(userRecordDetails.get(userQueue), 'first', baseUrl);
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
                mail.setHtmlBody(getBody(userRecordDetails.get(userQueue), 'first', baseUrl));
                mail.setOrgWideEmailAddressId(owea);
                mail.setTreatTargetObjectAsRecipient(true);
                emails.add(mail);
            }
        }
        Messaging.sendEmail(emails);
    }
    
    private static void sendSecondNotification(Map<Id,List<Id>> userRecordDetails, Map<Id, List<Id>> queueDetails, Id owea){
        if(userRecordDetails.isEmpty()){
            return;
        }
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for(Id userQueue : userRecordDetails.keySet()){
            if(queueDetails.containsKey(userQueue)){
                String emailBody = getBody(userRecordDetails.get(userQueue), 'second', baseUrl);
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
                mail.setHtmlBody(getBody(userRecordDetails.get(userQueue), 'second', baseUrl));
                mail.setOrgWideEmailAddressId(owea);
                mail.setTreatTargetObjectAsRecipient(true);
                emails.add(mail);
            }
        }
        Messaging.sendEmail(emails);
    }
    
    private static void sendUrgentNotification(Map<Id,List<Id>> userRecordDetails, Map<Id, List<Id>> queueDetails, Id owea){
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
            mail.setHtmlBody(getBody(userRecordDetails.get(userQueue), 'breached', baseUrl));
            mail.setOrgWideEmailAddressId(owea);
            mail.setTreatTargetObjectAsRecipient(true);
            emails.add(mail);
        }
        Messaging.sendEmail(emails);
    }
    
    private static String getBody(List<Id> recordIds, String type, String baseUrl) {
        
        if (recordIds == null || recordIds.isEmpty()) {
            return '';
        }
        
        String body = '';
        
        if (type == 'first') {
            body = 'Please check the following RSC Complaints for which SLA is not met:<br/>';
        } else if (type == 'second') {
            body = 'Please check the following RSC Complaints for which SLA is about to breach:<br/>';
        } else {
            body = '<b>SLA breached for the following RSC Complaints and Assigned to you:</b><br/>';
        }
        
        for (Id recordId : recordIds) {
            body += '<a href="' + baseUrl +'/' + recordId + '">' + recordId + '</a><br/>';
        }
        
        return body.toString();
    }
    
}