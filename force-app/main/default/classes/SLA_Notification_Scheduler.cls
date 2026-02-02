public class SLA_Notification_Scheduler implements Schedulable{
    public void execute(SchedulableContext sc) {
        SLA_Notification slaNotification = new SLA_Notification();
        Database.executeBatch(slaNotification, 100);
    }
}