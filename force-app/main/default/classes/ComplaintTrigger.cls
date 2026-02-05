/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ComplaintTrigger
 * Author          : Sandeep.R
 * Created Date    : Jan 15, 2026
 * Last Modified By: Sandeep.R
 * Last Modified On: Jan 15, 2026
 * Description     : Handler class for ComplaintTrigger trigger
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 15, 2026  │ Sandeep.R    │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ComplaintTrigger {
    public static void handler() {
        if(Trigger.isBefore && Trigger.isUpdate){
            beforeUpdate((List<RSC_Complaint__c>) Trigger.new, (Map<Id, RSC_Complaint__c>) Trigger.oldMap);
        }
    }
    
    private static void beforeUpdate(List<RSC_Complaint__c> newComplaints, Map<Id, RSC_Complaint__c> oldComplaints) {
        Map<String, Id> queueMap = new Map<String, Id>();
        Set<Id> queueIds = new Set<Id>();
        for(QueueSobject qs : [SELECT Id, QueueId, SobjectType, Queue.DeveloperName FROM QueueSobject WHERE SobjectType = 'RSC_Complaint__c' WITH SECURITY_ENFORCED]){
            queueMap.put(qs.Queue.DeveloperName, qs.QueueId);
            if(qs.Queue.DeveloperName == 'RSC_High' || qs.Queue.DeveloperName == 'RSC_Urgent'){
                queueIds.add(qs.QueueId);
            }
        }

        if(Test.isRunningTest()){
            List<String> groupList = new List<String>{'RSC_High', 'RSC_Medium', 'RSC_Normal', 'RSC_Urgent'};
            for(Group queueName : [SELECT Id, DeveloperName FROM Group  WHERE DeveloperName IN:groupList]){
                queueMap.put(queueName.DeveloperName, queueName.Id);
                if(queueName.DeveloperName == 'RSC_High' || queueName.DeveloperName == 'RSC_Urgent'){
                    queueIds.add(queueName.Id);
                }
            }
        }
        
        Map<Id, List<Id>> queueUserMap = getQueueUsers(queueIds);
        
        Map<Id, Integer> userComplaintCount = queueUserMap.isEmpty() ? new Map<Id, Integer>() : getUserComplaintCount(queueUserMap);
        
        for (RSC_Complaint__c comp : newComplaints) {
            if(comp.Is_Approved__c == true){
                if(oldComplaints.get(comp.Id).Is_Approved__c == false){
                    comp.Approved_By__c = UserInfo.getUserId();
                }
                if(comp.Assigned_To__c  != null && (oldComplaints.get(comp.Id).Assigned_To__c == null || oldComplaints.get(comp.Id).Assigned_To__c != comp.Assigned_To__c)){
                    comp.ownerId = comp.Assigned_To__c;
                }else if(comp.Assigned_To__c == null &&( !queueMap.values().contains(comp.ownerId) || oldComplaints.get(comp.Id).Priority__c != comp.Priority__c)){
                    if(comp.Priority__c == 'High' || comp.Priority__c == 'Urgent'){
                        Id userId = getMinComplaintUser(userComplaintCount);
                        comp.ownerId = userId;//queueMap.get('RSC_High');
                        comp.Assigned_To__c =userId;
                        userComplaintCount.put(userId, userComplaintCount.get(userId) + 1);
                    } else if(comp.Priority__c == 'Medium' && queueMap.containsKey('RSC_Medium')){
                        comp.ownerId = queueMap.get('RSC_Medium');
                    } else {
                        comp.ownerId = queueMap.get('RSC_Normal');
                    }
                }
            }
        }
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
    
    private static Map<Id, Integer> getUserComplaintCount(Map<Id, List<Id>> queueUserMap) {
        Map<Id, Integer> userComplaintCount = new Map<Id, Integer>();
        
        Set<Id> allUserIds = new Set<Id>();
        
        for (List<Id> userIds : queueUserMap.values()) {
            allUserIds.addAll(userIds);
        }
        
        for(AggregateResult comp : [SELECT OwnerId, count(Id) cmpCount FROM RSC_Complaint__c WHERE OwnerId IN:allUserIds AND Is_Approved__c = true AND Status__c != 'Resolved' AND Status__c != 'Closed' GROUP BY OwnerId]){
            userComplaintCount.put((Id) comp.get('OwnerId'), (Integer) comp.get('cmpCount'));
        }

        for(Id userId : allUserIds){
            if(!userComplaintCount.containsKey(userId)){
                userComplaintCount.put(userId, 0);
            }
        }
        
        return userComplaintCount;
    }
    
    private static Id getMinComplaintUser(Map<Id, Integer> userComplaintCount){
        if(userComplaintCount.isEmpty()){
            return UserInfo.getUserId();
        }

        Id minKey;
        Integer minCount;
        
        for (Id key : userComplaintCount.keySet()) {
            Integer countVal = userComplaintCount.get(key);
            if(countVal == 0){
                return key;
            }
            if (minCount == null || countVal < minCount) {
                minCount = countVal;
                minKey = key;
            }
        }

        return minKey;
    }
}