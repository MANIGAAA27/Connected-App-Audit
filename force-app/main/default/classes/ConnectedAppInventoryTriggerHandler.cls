public with sharing class ConnectedAppInventoryTriggerHandler {
    public static void beforeInsert(List<Connected_App_Inventory__c> newList) {
        if (newList == null) return;
        for (Connected_App_Inventory__c rec : newList) {
            if (rec.Last_Review_Date__c == null) {
                rec.Last_Review_Date__c = Date.today();
            }
        }
    }

    public static void beforeUpdate(List<Connected_App_Inventory__c> newList, Map<Id, Connected_App_Inventory__c> oldMap) {
        ConnectedAppInventoryService.validateOwnerAndPurpose(newList, oldMap);

        for (Connected_App_Inventory__c rec : newList) {
            Connected_App_Inventory__c oldRec = oldMap == null ? null : oldMap.get(rec.Id);
            if (oldRec != null && rec.Status__c != oldRec.Status__c) {
                rec.Last_Review_Date__c = Date.today();
            }
        }
    }
}