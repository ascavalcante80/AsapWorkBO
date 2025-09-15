import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/api_service.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final FirestoreWrapper _firestoreWrapper = FirestoreWrapper();
  List<Company> _companies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final companies = await _firestoreWrapper.getAllCompanies();
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Companies')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F0F23), const Color(0xFF1A1B36).withOpacity(0.8)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 80.0, right: 80.0, top: 24.0, bottom: 0.0),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50.0, right: 50.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateCompanyScreen()),
            ).then((_) => _loadCompanies());
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Company'),
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
            ElevatedButton(onPressed: _loadCompanies, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_companies.isEmpty) {
      return const Center(child: Text('No companies found'));
    }

    return RefreshIndicator(
      onRefresh: _loadCompanies,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _companies.length,
        itemBuilder: (context, index) {
          final company = _companies[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: Icon(Icons.business_rounded, size: 28, color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          if (company.primaryContact != null) ...[
                            Row(
                              children: [
                                Icon(Icons.person_rounded, size: 16, color: Colors.white.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Primary: ${company.primaryContact}',
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (company.secondaryContact != null) ...[
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 16, color: Colors.white.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Secondary: ${company.secondaryContact}',
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              Icon(Icons.fingerprint_rounded, size: 16, color: Colors.white.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Text(
                                'ID: ${company.id}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.5),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CreateCompanyScreen extends StatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  State<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends State<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreWrapper _firestoreWrapper = FirestoreWrapper();

  // Form controllers
  final _nameController = TextEditingController();
  final _primaryContactController = TextEditingController();
  final _secondaryContactController = TextEditingController();
  final _hubspotIdController = TextEditingController();

  // Loading state
  bool _isLoading = false;

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final company = Company(
        id: '',
        // Will be generated by Firestore
        name: _nameController.text.trim(),
        primaryContact: _primaryContactController.text.trim().isEmpty ? null : _primaryContactController.text.trim(),
        secondaryContact:
            _secondaryContactController.text.trim().isEmpty ? null : _secondaryContactController.text.trim(),
        hubspotId: _hubspotIdController.text.trim().isEmpty ? null : _hubspotIdController.text.trim(),
      );

      await _firestoreWrapper.createCompany(company);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company created successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating company: $e')));
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
    _primaryContactController.dispose();
    _secondaryContactController.dispose();
    _hubspotIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Company')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF0F0F23), const Color(0xFF1A1B36).withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1B36),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Company Information',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a new company to your network',
                          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Company Name *', border: OutlineInputBorder()),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a company name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _primaryContactController,
                          decoration: const InputDecoration(
                            labelText: 'Primary Contact (Optional)',
                            prefixIcon: Icon(Icons.person_rounded),
                            hintText: 'Contact ID or reference',
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _secondaryContactController,
                          decoration: const InputDecoration(
                            labelText: 'Secondary Contact (Optional)',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            hintText: 'Contact ID or reference',
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _hubspotIdController,
                          decoration: const InputDecoration(
                            labelText: 'HubSpot ID (Optional)',
                            prefixIcon: Icon(Icons.integration_instructions_rounded),
                            hintText: 'Enter HubSpot ID if available',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createCompany,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                  : const Text('Create Company'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
