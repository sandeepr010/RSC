public with sharing class ComplaintTrigger {
    public static void handler() {
        if(Trigger.isBefore && Trigger.isUpdate){
            beforeUpdate((List<RSC_Complaint__c>) Trigger.new, (Map<Id, RSC_Complaint__c>) Trigger.oldMap);
        }
    }
    
    private static void beforeUpdate(List<RSC_Complaint__c> newComplaints, Map<Id, RSC_Complaint__c> oldComplaints) {
        Map<String, Id> queueMap = new Map<String, Id>();
        for(QueueSobject qs : [SELECT Id, QueueId, SobjectType, Queue.DeveloperName FROM QueueSobject WHERE SobjectType = 'RSC_Complaint__c' WITH SECURITY_ENFORCED]){
            queueMap.put(qs.Queue.DeveloperName, qs.QueueId);
        }
        
        for (RSC_Complaint__c comp : newComplaints) {
            if(comp.Is_Approved__c == true){
                if(comp.Assigned_To__c  != null && (oldComplaints.get(comp.Id).Assigned_To__c == null || oldComplaints.get(comp.Id).Assigned_To__c != comp.Assigned_To__c)){
                    comp.ownerId = comp.Assigned_To__c;
                }else if(comp.Assigned_To__c == null &&( !queueMap.values().contains(comp.ownerId) || oldComplaints.get(comp.Id).Priority__c != comp.Priority__c)){
                    if(comp.Priority__c == 'High' && queueMap.containsKey('RSC_High')){
                        comp.ownerId = queueMap.get('RSC_High');
                    } else if(comp.Priority__c == 'Medium' && queueMap.containsKey('RSC_Medium')){
                        comp.ownerId = queueMap.get('RSC_Medium');
                    } else {
                        comp.ownerId = queueMap.get('RSC_Normal');
                    }
                }
            }
        }
    }
}