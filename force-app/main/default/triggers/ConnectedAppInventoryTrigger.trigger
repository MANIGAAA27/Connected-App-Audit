trigger ConnectedAppInventoryTrigger on Connected_App_Inventory__c (
    before insert,
    before update,
    before delete,
    after update
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ConnectedAppInventoryTriggerHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ConnectedAppInventoryTriggerHandler.handleBeforeUpdate(
                Trigger.new, Trigger.oldMap
            );
        } else if (Trigger.isDelete) {
            ConnectedAppInventoryTriggerHandler.handleBeforeDelete(Trigger.old);
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            ConnectedAppInventoryTriggerHandler.handleAfterUpdate(
                Trigger.new, Trigger.oldMap
            );
        }
    }
}
