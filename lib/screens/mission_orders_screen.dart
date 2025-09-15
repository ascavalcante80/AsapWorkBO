import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/company.dart';
import '../models/contact.dart';
import '../models/mission_order.dart';
import '../services/api_service.dart';

class MissionOrdersScreen extends StatefulWidget {
  const MissionOrdersScreen({super.key});

  @override
  State<MissionOrdersScreen> createState() => _MissionOrdersScreenState();
}

class _MissionOrdersScreenState extends State<MissionOrdersScreen> {
  final FirestoreWrapper _firestoreWrapper = FirestoreWrapper();
  final FunctionWrapper _functionsWrapper = FunctionWrapper();
  List<MissionOrder> _missionOrders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMissionOrders();
  }

  Future<void> _loadMissionOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final missionOrders = await _firestoreWrapper.getAllMissionOrders();
      setState(() {
        _missionOrders = missionOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(MissionOrderStatus status) {
    switch (status) {
      case MissionOrderStatus.draft:
        return Colors.grey;
      case MissionOrderStatus.published:
        return Colors.blue;
      case MissionOrderStatus.interview:
        return Colors.orange;
      case MissionOrderStatus.hired:
        return Colors.green;
      case MissionOrderStatus.closed:
        return Colors.red;
    }
  }

  Future<void> _deleteMissionOrder(MissionOrder order) async {
    if (order.hubspotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete: No HubSpot ID found')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Mission Order'),
          content: Text('Are you sure you want to delete "${order.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _functionsWrapper.deleteDealOnHubSpot(order.hubspotId!);
        await _firestoreWrapper.deleteMissionOrder(order);
        await _loadMissionOrders();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Mission order deleted successfully')));
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete mission order: $e')));
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mission Orders')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F0F23), const Color(0xFF1A1B36).withOpacity(0.8)],
          ),
        ),
        child: _buildBody(),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50, right: 50),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateMissionScreen()),
            ).then((_) => _loadMissionOrders());
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create New Mission'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMissionOrders, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_missionOrders.isEmpty) {
      return const Center(child: Text('No mission orders found'));
    }

    return Padding(
      padding: const EdgeInsets.only(left: 80.0, right: 80.0, top: 20.0, bottom: 30.0),
      child: RefreshIndicator(
        onRefresh: _loadMissionOrders,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _missionOrders.length,
          itemBuilder: (context, index) {
            final order = _missionOrders[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.all(20),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.work_rounded, color: Colors.white, size: 24),
                  ),
                  title: Text(
                    order.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(order.jobTitle, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getStatusColor(order.status), width: 1),
                        ),
                        child: Text(
                          order.status.toString().split('.').last.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EditMissionOrderScreen(missionOrder: order)),
                            ).then((_) => _loadMissionOrders());
                          },
                          tooltip: 'Edit Mission Order',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                        child: IconButton(
                          icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
                          onPressed: () => _deleteMissionOrder(order),
                          tooltip: 'Delete Mission Order',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F23),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Type', order.type.name, Icons.category_rounded),
                          _buildDetailRow('Location', order.location, Icons.location_on_rounded),
                          _buildDetailRow('Amount', order.amount, Icons.attach_money_rounded),
                          _buildDetailRow('Deal Stage', order.stage.id, Icons.timeline_rounded),
                          _buildDetailRow(
                            'Start Date',
                            order.startDate.toLocal().toString().split(' ')[0],
                            Icons.calendar_today_rounded,
                          ),
                          _buildDetailRow(
                            'End Date',
                            order.endDate.toLocal().toString().split(' ')[0],
                            Icons.event_rounded,
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Contacts',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          if (order.contacts.isNotEmpty)
                            ...order.contacts.map(
                              (contact) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                    Text(contact.email, style: TextStyle(color: Colors.white.withOpacity(0.8))),
                                    Text(
                                      contact.type.toString().split('.').last.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          const Text(
                            'Companies',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          if (order.companies.isNotEmpty)
                            ...order.companies.map(
                              (company) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      company.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                    if (company.primaryContact != null)
                                      Text(
                                        'Primary: ${company.primaryContact}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                      ),
                                    if (company.secondaryContact != null)
                                      Text(
                                        'Secondary: ${company.secondaryContact}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          if (order.notes.isNotEmpty) ...[
                            const Text(
                              'Notes',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF6366F1), width: 1),
                              ),
                              child: Text(order.notes, style: TextStyle(color: Colors.white.withOpacity(0.9))),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}

class CreateMissionScreen extends StatefulWidget {
  const CreateMissionScreen({super.key});

  @override
  State<CreateMissionScreen> createState() => _CreateMissionScreenState();
}

class _CreateMissionScreenState extends State<CreateMissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreWrapper _firestoreWrapper = FirestoreWrapper();

  // Form controllers
  final _nameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _locationController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DropAndDownDealStage dropAndDownDealStage = DropAndDownDealStage(
    selectedStage: SalesPipelineStage.appointmentScheduled,
  );

  // Selected values
  MissionOrderType _selectedType = MissionOrderType.contract;
  MissionOrderStatus _selectedStatus = MissionOrderStatus.draft;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  Contact? _selectedContact;
  Company? _selectedCompany;

  // Lists for dropdowns
  List<Contact> _contacts = [];
  List<Company> _companies = [];

  // Loading states
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _error = null;
      });

      final contacts = await _firestoreWrapper.getAllContacts();
      final companies = await _firestoreWrapper.getAllCompanies();

      setState(() {
        _contacts = contacts;
        _companies = companies;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingData = false;
      });
    }
  }

  Future<void> _createMissionOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContact == null || _selectedCompany == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select both contact and company')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final missionOrder = MissionOrder(
        id: '',
        // Will be generated by the server
        name: _nameController.text.trim(),
        type: _selectedType,
        jobTitle: _jobTitleController.text.trim(),
        location: _locationController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        stage: dropAndDownDealStage.selectedStage!,
        status: _selectedStatus,
        amount: _amountController.text.trim(),
        notes: _notesController.text.trim(),
        contacts: [_selectedContact!],
        companies: [_selectedCompany!],
      );

      await _firestoreWrapper.createMissionOrder(missionOrder);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mission order created successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating mission order: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 30));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobTitleController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Mission Order'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadInitialData, child: const Text('Retry')),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.only(left: 80.0, right: 80.0, top: 20.0, bottom: 30.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Mission Name *', border: OutlineInputBorder()),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a mission name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _jobTitleController,
                          decoration: const InputDecoration(labelText: 'Job Title *', border: OutlineInputBorder()),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a job title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<MissionOrderType>(
                          value: _selectedType,
                          decoration: const InputDecoration(labelText: 'Type *', border: OutlineInputBorder()),
                          items:
                              MissionOrderType.values.map((type) {
                                return DropdownMenuItem(value: type, child: Text(type.toString().split('.').last));
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(labelText: 'Location *', border: OutlineInputBorder()),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount *',
                            border: OutlineInputBorder(),
                            hintText: 'Enter amount in numbers only (e.g., 5000)',
                          ),
                          inputFormatters: [
                            // number only
                            FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*$')),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an amount';
                            }
                            // validate amount has number only
                            if (RegExp(r'^[0-9]*$').hasMatch(value) == false) {
                              return 'HubSpot only accepts numbers for amount';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date *',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(_startDate.toLocal().toString().split(' ')[0]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, false),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'End Date *',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(_endDate.toLocal().toString().split(' ')[0]),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<MissionOrderStatus>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                          items:
                              MissionOrderStatus.values.map((status) {
                                return DropdownMenuItem(value: status, child: Text(status.toString().split('.').last));
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedStatus = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        dropAndDownDealStage,

                        const SizedBox(height: 16),

                        DropdownButtonFormField<Contact>(
                          value: _selectedContact,
                          decoration: const InputDecoration(labelText: 'Contact *', border: OutlineInputBorder()),
                          items:
                              _contacts.map((contact) {
                                return DropdownMenuItem(
                                  value: contact,
                                  child: Text('${contact.fullName} (${contact.email})'),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedContact = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a contact';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<Company>(
                          value: _selectedCompany,
                          decoration: const InputDecoration(labelText: 'Company *', border: OutlineInputBorder()),
                          items:
                              _companies.map((company) {
                                return DropdownMenuItem(value: company, child: Text(company.name));
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCompany = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a company';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                            hintText: 'Enter each note on a new line',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _createMissionOrder,
                                child:
                                    _isLoading
                                        ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                        : const Text('Create Mission Order'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}

class ContactsMissionOrdersScreen extends StatefulWidget {
  final Contact contact;

  const ContactsMissionOrdersScreen({super.key, required this.contact});

  @override
  State<ContactsMissionOrdersScreen> createState() => _ContactsMissionOrdersScreenState();
}

class _ContactsMissionOrdersScreenState extends State<ContactsMissionOrdersScreen> {
  final FirestoreWrapper _firestoreWrapper = FirestoreWrapper();
  List<MissionOrder> _missionOrders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContactMissionOrders();
  }

  Future<void> _loadContactMissionOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final allMissionOrders = await _firestoreWrapper.getAllMissionOrders();

      // Filter mission orders where this contact is involved
      final contactMissionOrders =
          allMissionOrders.where((order) {
            return order.contacts.any((contact) => contact.id == widget.contact.id);
          }).toList();

      setState(() {
        _missionOrders = contactMissionOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(MissionOrderStatus status) {
    switch (status) {
      case MissionOrderStatus.draft:
        return Colors.grey;
      case MissionOrderStatus.published:
        return Colors.blue;
      case MissionOrderStatus.interview:
        return Colors.orange;
      case MissionOrderStatus.hired:
        return Colors.green;
      case MissionOrderStatus.closed:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.contact.fullName} - Mission Orders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(children: [_buildContactHeader(), const Divider(), Expanded(child: _buildMissionOrdersList())]),
    );
  }

  Widget _buildContactHeader() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              child: Text(
                '${widget.contact.firstName[0]}${widget.contact.lastName[0]}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contact.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(widget.contact.email, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(widget.contact.type.toString().split('.').last),
                    backgroundColor:
                        widget.contact.type == ContactType.internal ? Colors.green.shade100 : Colors.blue.shade100,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionOrdersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadContactMissionOrders, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_missionOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No mission orders found for this contact'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContactMissionOrders,
      child: ListView.builder(
        itemCount: _missionOrders.length,
        itemBuilder: (context, index) {
          final order = _missionOrders[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ExpansionTile(
              leading: Icon(Icons.work, color: _getStatusColor(order.status)),
              title: Text(order.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.jobTitle),
                  Chip(
                    label: Text(order.status.toString().split('.').last),
                    backgroundColor: _getStatusColor(order.status).withValues(alpha: 0.2),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ${order.type.toString().split('.').last}'),
                      Text('Location: ${order.location}'),
                      Text('Amount: ${order.amount}'),
                      Text('Deal Stage: ${order.stage.id}'),
                      Text('Start Date: ${order.startDate.toLocal().toString().split(' ')[0]}'),
                      Text('End Date: ${order.endDate.toLocal().toString().split(' ')[0]}'),
                      const SizedBox(height: 12),
                      const Text('Contacts:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (order.contacts.isNotEmpty)
                        ...order.contacts
                            .map(
                              (contact) => Card(
                                color: Colors.blue.shade50,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Name: ${contact.fullName}'),
                                      Text('Email: ${contact.email}'),
                                      Text('Type: ${contact.type.toString().split('.').last}'),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      const SizedBox(height: 12),
                      const Text('Companies:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (order.companies.isNotEmpty)
                        ...order.companies
                            .map(
                              (company) => Card(
                                color: Colors.green.shade50,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Name: ${company.name}'),
                                      if (company.primaryContact != null)
                                        Text('Primary Contact: ${company.primaryContact}'),
                                      if (company.secondaryContact != null)
                                        Text('Secondary Contact: ${company.secondaryContact}'),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      const SizedBox(height: 12),
                      Text('Notes: ${order.notes}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EditMissionOrderScreen extends StatefulWidget {
  final MissionOrder missionOrder;

  const EditMissionOrderScreen({super.key, required this.missionOrder});

  @override
  State<EditMissionOrderScreen> createState() => _EditMissionOrderScreenState();
}

class _EditMissionOrderScreenState extends State<EditMissionOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreWrapper _firestoreWrapper = FirestoreWrapper();
  DropAndDownDealStage dropAndDownDealStage = DropAndDownDealStage();

  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _locationController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  // Selected values
  late MissionOrderType _selectedType;
  late MissionOrderStatus _selectedStatus;

  // late SalesPipelineStage _selectedStage;
  late DateTime _startDate;
  late DateTime _endDate;
  List<Contact> _selectedContacts = [];
  List<Company> _selectedCompanies = [];

  // Available data
  List<Contact> _contacts = [];
  List<Company> _companies = [];

  // Loading states
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInitialData();
  }

  void _initializeControllers() {
    dropAndDownDealStage.selectedStage = widget.missionOrder.stage;
    final order = widget.missionOrder;
    _nameController = TextEditingController(text: order.name);
    _jobTitleController = TextEditingController(text: order.jobTitle);
    _locationController = TextEditingController(text: order.location);
    _amountController = TextEditingController(text: order.amount);
    _notesController = TextEditingController(text: order.notes);

    _selectedType = order.type;
    _selectedStatus = order.status;
    // _selectedStage = order.stage;
    _startDate = order.startDate;
    _endDate = order.endDate;
    _selectedContacts = List.from(order.contacts);
    _selectedCompanies = List.from(order.companies);
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _error = null;
      });

      final contacts = await _firestoreWrapper.getAllContacts();
      final companies = await _firestoreWrapper.getAllCompanies();

      setState(() {
        _contacts = contacts;
        _companies = companies;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingData = false;
      });
    }
  }

  Future<void> _updateMissionOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one contact')));
      return;
    }
    if (_selectedCompanies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one company')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedMissionOrder = widget.missionOrder.copyWith(
        name: _nameController.text.trim(),
        type: _selectedType,
        jobTitle: _jobTitleController.text.trim(),
        location: _locationController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        status: _selectedStatus,
        stage: dropAndDownDealStage.selectedStage,
        amount: _amountController.text.trim(),
        notes: _notesController.text.trim(),
        contacts: _selectedContacts,
        companies: _selectedCompanies,
        hubspotId: widget.missionOrder.hubspotId,
      );

      await _firestoreWrapper.updateMissionOrder(updatedMissionOrder);
      await _firestoreWrapper.hubSpotWrapper.updateDealOnHubSpot(updatedMissionOrder);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mission order updated successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating mission order: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobTitleController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Mission Order'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Mission Order'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadInitialData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Mission Order'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 80.0, right: 80.0, top: 20.0, bottom: 30.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Mission Order Name *', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a mission order name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<MissionOrderType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Type *', border: OutlineInputBorder()),
                  items:
                      MissionOrderType.values.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type.toString().split('.').last));
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _jobTitleController,
                  decoration: const InputDecoration(labelText: 'Job Title *', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a job title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location *', border: OutlineInputBorder()),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start Date *', border: OutlineInputBorder()),
                          child: Text(_startDate.toLocal().toString().split(' ')[0]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'End Date *', border: OutlineInputBorder()),
                          child: Text(_endDate.toLocal().toString().split(' ')[0]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<MissionOrderStatus>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                  items:
                      MissionOrderStatus.values.map((status) {
                        return DropdownMenuItem(value: status, child: Text(status.toString().split('.').last));
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                dropAndDownDealStage,
                const SizedBox(height: 16),

                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                  inputFormatters: [
                    // number only
                    FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*$')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    // validate amount has number only
                    if (RegExp(r'^[0-9]*$').hasMatch(value) == false) {
                      return 'HubSpot only accepts numbers for amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contacts selection
                const Text('Contacts *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      if (_selectedContacts.isNotEmpty)
                        ..._selectedContacts
                            .map(
                              (contact) => ListTile(
                                title: Text(contact.fullName),
                                subtitle: Text(contact.email),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () {
                                    setState(() {
                                      _selectedContacts.remove(contact);
                                    });
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Add Contact'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Select Contact'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _contacts.length,
                                      itemBuilder: (context, index) {
                                        final contact = _contacts[index];
                                        final isSelected = _selectedContacts.contains(contact);
                                        return ListTile(
                                          title: Text(contact.fullName),
                                          subtitle: Text(contact.email),
                                          trailing: isSelected ? const Icon(Icons.check) : null,
                                          onTap: () {
                                            if (!isSelected) {
                                              setState(() {
                                                _selectedContacts.add(contact);
                                              });
                                            }
                                            Navigator.pop(context);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ],
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Companies selection
                const Text('Companies *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      if (_selectedCompanies.isNotEmpty)
                        ..._selectedCompanies
                            .map(
                              (company) => ListTile(
                                title: Text(company.name),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () {
                                    setState(() {
                                      _selectedCompanies.remove(company);
                                    });
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Add Company'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Select Company'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _companies.length,
                                      itemBuilder: (context, index) {
                                        final company = _companies[index];
                                        final isSelected = _selectedCompanies.contains(company);
                                        return ListTile(
                                          title: Text(company.name),
                                          trailing: isSelected ? const Icon(Icons.check) : null,
                                          onTap: () {
                                            if (!isSelected) {
                                              setState(() {
                                                _selectedCompanies.add(company);
                                              });
                                            }
                                            Navigator.pop(context);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ],
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateMissionOrder,
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DropAndDownDealStage extends StatefulWidget {
  SalesPipelineStage? selectedStage;

  DropAndDownDealStage({super.key, this.selectedStage});

  @override
  State<DropAndDownDealStage> createState() => _DropAndDownDealStageState();
}

class _DropAndDownDealStageState extends State<DropAndDownDealStage> {
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SalesPipelineStage>(
      value: widget.selectedStage,
      decoration: const InputDecoration(labelText: 'Pipeline Stage *', border: OutlineInputBorder()),
      items:
          SalesPipelineStage.values.map((stage) {
            return DropdownMenuItem(value: stage, child: Text(salesPipelineStageLabels[stage]!));
          }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            widget.selectedStage = value;
          });
        }
      },
    );
  }
}
