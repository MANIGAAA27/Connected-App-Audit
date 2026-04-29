public with sharing class ConnectedAppInventoryController {
    @AuraEnabled(cacheable=true)
    public static List<ConnectedAppInventoryService.InventoryRow> getInventory(String searchKey, String statusFilter) {
        return ConnectedAppInventoryService.fetchInventory(searchKey, statusFilter, 2000);
    }

    @AuraEnabled(cacheable=true)
    public static ConnectedAppInventoryService.Summary getSummary() {
        return ConnectedAppInventoryService.getSummary();
    }
}