@isTest
public class ConnectedAppInventoryTriggerHandlerTest {
    @isTest
    static void testBeforeInsertDefaultsLastReviewDate() {
        Connected_App_Inventory__c rec = new Connected_App_Inventory__c(
            Name = 'INV-TRG-1',
            App_Name__c = 'Test App',
            App_Type__c = 'Custom',
            Status__c = 'Dormant',
            Risk_Classification__c = 'Low'
        );

        Test.startTest();
        insert rec;
        Test.stopTest();

        Connected_App_Inventory__c inserted = [
            SELECT Last_Review_Date__c
            FROM Connected_App_Inventory__c
            WHERE Id = :rec.Id
        ];
        System.assertEquals(Date.today(), inserted.Last_Review_Date__c, 'Last review should default to today');
    }

    @isTest
    static void testPreventActivateWithoutOwnersAndPurpose() {
        Connected_App_Inventory__c rec = new Connected_App_Inventory__c(
            Name = 'INV-TRG-2',
            App_Name__c = 'Needs Owners',
            App_Type__c = 'Managed',
            Status__c = 'Dormant',
            Risk_Classification__c = 'Medium'
        );
        insert rec;

        rec.Status__c = 'Active';

        Test.startTest();
        try {
            update rec;
            System.assert(false, 'Update should have thrown a DmlException due to addError');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(System.Label.CAAG_Activate_Requires_Owners_And_Purpose),
                'Expected validation message'
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testActivateWithOwnersAndPurposeAllowed() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Connected_App_Inventory__c rec = new Connected_App_Inventory__c(
            Name = 'INV-TRG-3',
            App_Name__c = 'Ready App',
            App_Type__c = 'Custom',
            Status__c = 'Dormant',
            Risk_Classification__c = 'Low',
            Business_Owner__c = u.Id,
            Technical_Owner__c = u.Id,
            Business_Purpose__c = 'Test purpose'
        );
        insert rec;

        Date before = rec.Last_Review_Date__c;

        rec.Status__c = 'Active';

        Test.startTest();
        update rec;
        Test.stopTest();

        Connected_App_Inventory__c updated = [
            SELECT Status__c, Last_Review_Date__c
            FROM Connected_App_Inventory__c
            WHERE Id = :rec.Id
        ];
        System.assertEquals('Active', updated.Status__c, 'Should be activated');
        System.assertEquals(Date.today(), updated.Last_Review_Date__c, 'Last review should update on status change');
        System.assertNotEquals(before, updated.Last_Review_Date__c, 'Last review should change from prior value');
    }
}