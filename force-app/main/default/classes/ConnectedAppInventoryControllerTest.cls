@isTest
public class ConnectedAppInventoryControllerTest {
    @testSetup
    static void setupData() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        List<Connected_App_Inventory__c> records = new List<Connected_App_Inventory__c>();
        records.add(new Connected_App_Inventory__c(
            Name = 'INV-001',
            App_Name__c = 'OwnBackup',
            App_Type__c = 'Managed',
            Status__c = 'Active',
            Risk_Classification__c = 'High',
            Business_Owner__c = u.Id,
            Technical_Owner__c = u.Id,
            Business_Purpose__c = 'Backup and restore',
            Last_Used_Date__c = Date.today().addDays(-2),
            Notes__c = 'Managed package app'
        ));
        records.add(new Connected_App_Inventory__c(
            Name = 'INV-002',
            App_Name__c = 'Workbench',
            App_Type__c = 'Custom',
            Status__c = 'Dormant',
            Risk_Classification__c = 'Critical',
            Business_Owner__c = u.Id,
            Technical_Owner__c = u.Id,
            Business_Purpose__c = 'Admin tool',
            Last_Used_Date__c = Date.today().addDays(-200),
            Notes__c = 'Internal tool'
        ));
        insert records;
    }

    @isTest
    static void testGetInventoryAll() {
        Test.startTest();
        List<ConnectedAppInventoryService.InventoryRow> rows =
            ConnectedAppInventoryController.getInventory(null, 'All');
        ConnectedAppInventoryService.Summary sum = ConnectedAppInventoryController.getSummary();
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Rows should be returned');
        System.assertEquals(2, rows.size(), 'Should return all records');
        System.assertEquals(2, sum.total, 'Total should match');
        System.assertEquals(1, sum.active, 'Active count should match');
        System.assertEquals(1, sum.dormant, 'Dormant count should match');
    }

    @isTest
    static void testGetInventorySearchAndFilter() {
        Test.startTest();
        List<ConnectedAppInventoryService.InventoryRow> rows =
            ConnectedAppInventoryController.getInventory('Work', 'Dormant');
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Should return filtered record');
        System.assertEquals('Workbench', rows[0].appName);
        System.assertEquals('Dormant', rows[0].status);
    }
}