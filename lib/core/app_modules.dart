import 'package:flutter/material.dart';

enum AppModule { cashier, accounts, inventory, hr }

extension AppModuleExtension on AppModule {
  String get arabicName {
    switch (this) {
      case AppModule.cashier:
        return 'كاشير';
      case AppModule.accounts:
        return 'حسابات';
      case AppModule.inventory:
        return 'مخزون';
      case AppModule.hr:
        return 'موارد بشرية';
    }
  }

  IconData get icon {
    switch (this) {
      case AppModule.cashier:
        return Icons.point_of_sale;
      case AppModule.accounts:
        return Icons.receipt_long;
      case AppModule.inventory:
        return Icons.inventory_2;
      case AppModule.hr:
        return Icons.badge;
    }
  }

  bool get isImplemented {
    switch (this) {
      case AppModule.cashier:
      case AppModule.inventory:
        return true;
      case AppModule.accounts:
      case AppModule.hr:
        return false;
    }
  }
}

List<AppModule> allowedModules() => AppModule.values;
