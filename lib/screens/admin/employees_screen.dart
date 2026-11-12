import 'package:flutter/material.dart';

import 'employees_tab.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Karyawan')),
      body: const EmployeesTab(),
    );
  }
}
