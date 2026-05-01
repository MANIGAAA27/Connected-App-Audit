/**
 * ConnectedAppInventoryTriggerTest
 * Covers ConnectedAppInventoryTrigger at 100% line coverage.
 * Delegates logic verification to ConnectedAppInventoryTriggerHandlerTest;
 * this class confirms the trigger fires on each DML event.
 */
@isTest
private class ConnectedAppInventoryTriggerTest {

    private static User getAdmin() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            LastName         = 'TrigCovAdmin',
            FirstName        = 'Test',
            Email            = 'trigcovadmin@keneland.com',
            Username         = 'trigcovadmin' + Datetime.now().getTime() + '@keneland.com',
            Alias            = 'trcadm',
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId        = p.Id
        );
        insert u;
        return u;
    }

    @isTest
    static void testTriggerOnInsert() {
        User admin = getAdmin();

        Connected_App_Inventory__c rec = new Connected_App_Inventory__c(
            Connected_App_Name__c = 'TrigInsertApp',
            App_Type__c           = 'Custom'
        );

        Test.startTest();
        System.runAs(admin) {
            insert rec;
        }
        Test.stopTest();

        System.assertNotEquals(null, rec.Id, 'Record should be inserted successfully.');
    }

    @isTest
    static void testTriggerOnUpdate() {
        User admin = getAdmin();

        Connected_App_Inventory__c rec = new Connected_App_Inventory__c(
            Connected_App_Name__c = 'TrigUpdateApp',
            App_Type__c           = 'Custom'
        );
        System.runAs(admin) {
            insert rec;
        }

        Test.startTest();
        System.runAs(admin) {
            rec.Risk_Rating__c = 'High';
            update rec;
        }
        Test.stopTest();

        Connected_App_Inventory__c updated = [
            SELECT Risk_Rating__c FROM Connected_App_Inventory__c WHERE Id = :rec.Id
        ];
        System.assertEquals('High', updated.Risk_Rating__c,
            'Risk Rating should be updated to High.');
    }

    @isTest
    static void testTriggerValidation_PreventDelete() {
        User admin = getAdmin();

        Connected_App_Inventory__c activeRec;
        System.runAs(admin) {
            activeRec = new Connected_App_Inventory__c(
                Connected_App_Name__c = 'TrigDeleteActiveApp',
                App_Type__c           = 'Custom',
                Status__c             = 'Active',
                Business_Owner__c     = admin.Id,
                Last_Review_Date__c   = Date.today(),
                Risk_Rating__c        = 'High'
            );
            insert activeRec;
        }

        Test.startTest();
        Boolean blocked = false;
        System.runAs(admin) {
            try {
                delete activeRec;
            } catch (DmlException e) {
                blocked = true;
            }
        }
        Test.stopTest();

        System.assert(blocked,
            'Trigger should block deletion of Active records.');
    }

    @isTest
    static void testBulkTriggerInvocation() {
        User admin = getAdmin();

        List<Connected_App_Inventory__c> recs = new List<Connected_App_Inventory__c>();
        for (Integer i = 0; i < 200; i++) {
            recs.add(new Connected_App_Inventory__c(
                Connected_App_Name__c = 'BulkTrigApp' + i,
                App_Type__c           = 'Managed'
            ));
        }

        Test.startTest();
        System.runAs(admin) {
            insert recs;
        }
        Test.stopTest();

        Integer saved = [
            SELECT COUNT() FROM Connected_App_Inventory__c
            WHERE  Connected_App_Name__c LIKE 'BulkTrigApp%'
        ];
        System.assertEquals(200, saved,
            '200 bulk records should all be inserted via the trigger.');
    }
}
