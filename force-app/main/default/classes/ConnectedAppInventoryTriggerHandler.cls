/**
 * ConnectedAppInventoryTriggerHandler
 * Centralised handler for Connected_App_Inventory__c trigger events.
 * Called by ConnectedAppInventoryTrigger — keeps trigger body thin.
 */
public with sharing class ConnectedAppInventoryTriggerHandler {

    // ─────────────────────────────────────────────────────────────────────────
    // Public entry points (called from trigger)
    // ─────────────────────────────────────────────────────────────────────────

    public static void handleBeforeInsert(List<Connected_App_Inventory__c> newRecords) {
        for (Connected_App_Inventory__c rec : newRecords) {
            applyDefaults(rec);
        }
    }

    public static void handleBeforeUpdate(
        List<Connected_App_Inventory__c> newRecords,
        Map<Id, Connected_App_Inventory__c> oldMap
    ) {
        for (Connected_App_Inventory__c rec : newRecords) {
            validateActiveOwner(rec, oldMap.get(rec.Id));
            stampReviewDate(rec, oldMap.get(rec.Id));
        }
    }

    public static void handleAfterUpdate(
        List<Connected_App_Inventory__c> newRecords,
        Map<Id, Connected_App_Inventory__c> oldMap
    ) {
        List<Connected_App_Inventory__c> ownerChanges =
            new List<Connected_App_Inventory__c>();

        for (Connected_App_Inventory__c rec : newRecords) {
            Connected_App_Inventory__c oldRec = oldMap.get(rec.Id);
            if (rec.Technical_Owner__c != oldRec.Technical_Owner__c &&
                rec.Technical_Owner__c != null) {
                ownerChanges.add(rec);
            }
        }

        if (!ownerChanges.isEmpty()) {
            notifyNewOwners(ownerChanges);
        }
    }

    public static void handleBeforeDelete(
        List<Connected_App_Inventory__c> oldRecords
    ) {
        for (Connected_App_Inventory__c rec : oldRecords) {
            if (rec.Status__c == 'Active') {
                rec.addError(
                    'Active Connected App records cannot be deleted. ' +
                    'Change the Status to Obsolete and complete a formal decommission.'
                );
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static void applyDefaults(Connected_App_Inventory__c rec) {
        if (String.isBlank(rec.Status__c)) {
            rec.Status__c = 'Under Review';
        }
        if (rec.Last_Review_Date__c == null) {
            rec.Last_Review_Date__c = Date.today();
        }
        if (String.isBlank(rec.Risk_Rating__c)) {
            rec.Risk_Rating__c = 'Medium';
        }
    }

    private static void validateActiveOwner(
        Connected_App_Inventory__c newRec,
        Connected_App_Inventory__c oldRec
    ) {
        if (newRec.Status__c == 'Active' && newRec.Business_Owner__c == null) {
            newRec.Business_Owner__c.addError(
                'A Business Owner is required when Status is Active (BR-001).'
            );
        }
    }

    private static void stampReviewDate(
        Connected_App_Inventory__c newRec,
        Connected_App_Inventory__c oldRec
    ) {
        // Auto-stamp Last_Review_Date__c whenever Status transitions to Active
        if (newRec.Status__c == 'Active' && oldRec.Status__c != 'Active') {
            newRec.Last_Review_Date__c = Date.today();
        }
    }

    private static void notifyNewOwners(
        List<Connected_App_Inventory__c> changed
    ) {
        Set<Id> ownerIds = new Set<Id>();
        for (Connected_App_Inventory__c rec : changed) {
            ownerIds.add(rec.Technical_Owner__c);
        }

        Map<Id, User> owners = new Map<Id, User>([
            SELECT Id, Email, Name
            FROM   User
            WHERE  Id IN :ownerIds
        ]);

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        OrgWideEmailAddress[] orgWide = [
            SELECT Id FROM OrgWideEmailAddress LIMIT 1
        ];

        for (Connected_App_Inventory__c rec : changed) {
            User owner = owners.get(rec.Technical_Owner__c);
            if (owner == null || String.isBlank(owner.Email)) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ owner.Email });
            mail.setSubject(
                'Connected App Ownership Assigned: ' + rec.Connected_App_Name__c
            );
            mail.setPlainTextBody(
                'Hi ' + owner.Name + ',\n\n' +
                'You have been assigned as Technical Owner of the connected app: ' +
                rec.Connected_App_Name__c + '.\n\n' +
                'Please review the record and confirm all details are accurate.\n\n' +
                'Connected App Governance System'
            );
            if (!orgWide.isEmpty()) {
                mail.setOrgWideEmailAddressId(orgWide[0].Id);
            }
            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }
}
