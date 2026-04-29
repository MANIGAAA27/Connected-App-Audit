trigger ConnectedAppInventoryTrigger on Connected_App_Inventory__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ConnectedAppInventoryTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ConnectedAppInventoryTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}