import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/studio_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/auth_required_dialog.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final ApiService _apiService = ApiService();
  late Future<CreatorStudioModel> _studioFuture;

  String _datePreset = 'all';
  String? _filterFrom;
  String? _filterTo;
  String _txTypeFilter = 'all'; // 'all', 'credit', 'debit'
  bool _hideBalance = false;
  bool _isSubmittingWithdrawal = false;
  bool _isSubmittingKyc = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final auth = AuthService.instance;
    setState(() {
      _studioFuture = _apiService.fetchStudioData(
        auth.token,
        auth.currentUser,
        _filterFrom,
        _filterTo,
        _txTypeFilter == 'all' ? null : _txTypeFilter,
      );
    });
  }

  void _onDatePresetSelected(String preset) async {
    final now = DateTime.now();
    String? from;
    String? to;

    if (preset == 'today') {
      from = now.toIso8601String().split('T').first;
      to = from;
    } else if (preset == '7d') {
      from = now.subtract(const Duration(days: 7)).toIso8601String().split('T').first;
      to = now.toIso8601String().split('T').first;
    } else if (preset == 'this_month') {
      from = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      to = now.toIso8601String().split('T').first;
    } else if (preset == '30d') {
      from = now.subtract(const Duration(days: 30)).toIso8601String().split('T').first;
      to = now.toIso8601String().split('T').first;
    } else if (preset == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2023),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(
          start: now.subtract(const Duration(days: 14)),
          end: now,
        ),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primaryBlue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        from = picked.start.toIso8601String().split('T').first;
        to = picked.end.toIso8601String().split('T').first;
      } else {
        return;
      }
    } else {
      // 'all'
      from = null;
      to = null;
    }

    setState(() {
      _datePreset = preset;
      _filterFrom = from;
      _filterTo = to;
    });
    _loadData();
  }

  void _onTxTypeChanged(String type) {
    setState(() {
      _txTypeFilter = type;
    });
    _loadData();
  }

  // --- KYC Resubmission / Submission Bottom Sheet ---
  void _openKycModal(BuildContext context, CreatorStudioModel studio) {
    final nameCtrl = TextEditingController(text: studio.kycHolderName.isNotEmpty ? studio.kycHolderName : studio.creatorName);
    final aadhaarCtrl = TextEditingController(text: studio.kycAadhaar);
    final panCtrl = TextEditingController(text: studio.kycPan);
    final bankCtrl = TextEditingController(text: studio.kycBank);
    final accountCtrl = TextEditingController(text: studio.kycAccount);
    final ifscCtrl = TextEditingController(text: studio.kycIfsc);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: AppColors.primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bank & Identity KYC',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Mandatory for direct bank payouts and milestones',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (studio.kycRejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.rose, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Previous Submission Rejected',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.rose),
                                  ),
                                  Text(
                                    studio.kycRejectionReason,
                                    style: const TextStyle(fontSize: 11, color: AppColors.rose),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildTextField('Account Holder Name *', nameCtrl, Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildTextField('12-Digit Aadhaar Number *', aadhaarCtrl, Icons.badge_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildTextField('PAN Card Number *', panCtrl, Icons.credit_card_outlined, textCapitalization: TextCapitalization.characters),
                    const SizedBox(height: 12),
                    _buildTextField('Bank Name *', bankCtrl, Icons.account_balance_outlined),
                    const SizedBox(height: 12),
                    _buildTextField('Bank Account Number *', accountCtrl, Icons.numbers_outlined, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildTextField('Bank IFSC Code *', ifscCtrl, Icons.qr_code_outlined, textCapitalization: TextCapitalization.characters),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmittingKyc
                            ? null
                            : () async {
                                final auth = AuthService.instance;
                                if (auth.token == null || auth.token!.isEmpty) return;

                                if (nameCtrl.text.trim().isEmpty ||
                                    aadhaarCtrl.text.trim().length < 12 ||
                                    panCtrl.text.trim().length < 10 ||
                                    bankCtrl.text.trim().isEmpty ||
                                    accountCtrl.text.trim().isEmpty ||
                                    ifscCtrl.text.trim().length < 11) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please fill all required KYC fields accurately.'),
                                      backgroundColor: AppColors.rose,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => _isSubmittingKyc = true);
                                final res = await _apiService.submitKyc(
                                  token: auth.token!,
                                  holderName: nameCtrl.text.trim(),
                                  aadhaar: aadhaarCtrl.text.trim(),
                                  pan: panCtrl.text.trim().toUpperCase(),
                                  bankName: bankCtrl.text.trim(),
                                  bankAccount: accountCtrl.text.trim(),
                                  ifsc: ifscCtrl.text.trim().toUpperCase(),
                                );
                                setModalState(() => _isSubmittingKyc = false);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (res['success'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('KYC documents submitted successfully! Admin review in progress.'),
                                        backgroundColor: AppColors.successGreen,
                                      ),
                                    );
                                    _loadData();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['error'] ?? 'Failed to submit KYC'),
                                        backgroundColor: AppColors.rose,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSubmittingKyc
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit KYC Documents', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Withdrawal Bottom Sheet ---
  void _openWithdrawalModal(BuildContext context, CreatorStudioModel studio) {
    final amountCtrl = TextEditingController(text: studio.availableBalance >= 500 ? '500' : '0');
    final double maxBalance = studio.availableBalance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.successGreen, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Bank Withdrawal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Instant wallet debit • Bank settlement via IMPS / NEFT',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Linked Bank Preview
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.canvasBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance, color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studio.kycBank.isNotEmpty ? studio.kycBank : 'Verified Bank Account',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  studio.kycAccount.length > 4
                                      ? 'A/C •••• ${studio.kycAccount.substring(studio.kycAccount.length - 4)} • IFSC: ${studio.kycIfsc}'
                                      : 'Account: ${studio.kycAccount}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Verified',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.successGreen),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Withdrawal Amount',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          'Available: ${_currencyFormat.format(maxBalance)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Amount Text Input
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text('₹', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        filled: true,
                        fillColor: AppColors.canvasBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    // Quick Amount Chips
                    Wrap(
                      spacing: 8,
                      children: [500, 1000, 2500, maxBalance.toInt()].toSet().map((amt) {
                        return ActionChip(
                          label: Text(amt == maxBalance.toInt() ? 'All (₹$amt)' : '₹$amt'),
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.surfaceBorder),
                          onPressed: () {
                            setModalState(() {
                              amountCtrl.text = amt.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      '• Minimum withdrawal: ₹500.00\n• Settlement: typically 1-2 business hours via IMPS\n• If rejected by bank, amount automatically refunds to wallet',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmittingWithdrawal
                            ? null
                            : () async {
                                final auth = AuthService.instance;
                                if (auth.token == null || auth.token!.isEmpty) return;

                                final enteredAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                                if (enteredAmount < 500) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Minimum withdrawal amount is ₹500.00'),
                                      backgroundColor: AppColors.rose,
                                    ),
                                  );
                                  return;
                                }
                                if (enteredAmount > maxBalance) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Withdrawal amount exceeds available liquid balance.'),
                                      backgroundColor: AppColors.rose,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => _isSubmittingWithdrawal = true);
                                final res = await _apiService.requestWithdrawal(
                                  amount: enteredAmount,
                                  token: auth.token!,
                                );
                                setModalState(() => _isSubmittingWithdrawal = false);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (res['success'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message'] ?? 'Payout request submitted successfully!'),
                                        backgroundColor: AppColors.successGreen,
                                      ),
                                    );
                                    _loadData();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['error'] ?? 'Withdrawal failed'),
                                        backgroundColor: AppColors.rose,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSubmittingWithdrawal
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Confirm Bank Payout', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.canvasBackground,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      appBar: AppBar(
        title: const Text(
          'Earnings & Settlements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Refresh Earnings',
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<CreatorStudioModel>(
        future: _studioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.rose),
                    const SizedBox(height: 12),
                    const Text('Unable to load earnings data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(snapshot.error?.toString() ?? 'Please check network connection and try again.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final studio = snapshot.data!;
          final filteredTransactions = studio.transactions.where((tx) {
            if (_txTypeFilter == 'credit') return tx.type == 'credit';
            if (_txTypeFilter == 'debit') return tx.type == 'debit';
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            color: AppColors.primaryBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. Hero Net Balance & Period Income Card ---
                  _buildBalanceHeroCard(studio),
                  const SizedBox(height: 16),

                  // --- 2. Interactive Date Preset Rail ---
                  _buildDateFilterRail(),
                  const SizedBox(height: 16),

                  // --- 3. Live KYC Approval Banner ---
                  _buildKycStatusBanner(studio),
                  const SizedBox(height: 16),

                  // --- 4. Earnings Streams Breakdown Cards ---
                  _buildEarningsBreakdownCards(studio),
                  const SizedBox(height: 20),

                  // --- 5. Transaction Ledger Header & Type Filter ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Audit & Settlement Ledger',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      // Filter chips
                      Row(
                        children: [
                          _buildTypeChip('All', 'all'),
                          const SizedBox(width: 4),
                          _buildTypeChip('Credits', 'credit'),
                          const SizedBox(width: 4),
                          _buildTypeChip('Debits', 'debit'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // --- 6. Transactions List ---
                  if (filteredTransactions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textSecondary),
                          SizedBox(height: 8),
                          Text('No transactions found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('No entries match the selected period and filter.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTransactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = filteredTransactions[index];
                        final isCredit = tx.type == 'credit';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isCredit
                                      ? AppColors.successGreen.withValues(alpha: 0.12)
                                      : AppColors.rose.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: isCredit ? AppColors.successGreen : AppColors.rose,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd MMM yyyy • hh:mm a').format(tx.date),
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isCredit ? '+' : '-'}${_currencyFormat.format(tx.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isCredit ? AppColors.successGreen : AppColors.rose,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isCredit
                                          ? AppColors.successGreen.withValues(alpha: 0.1)
                                          : Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isCredit ? 'Settled' : 'Processed',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isCredit ? AppColors.successGreen : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Hero Net Balance Card ---
  Widget _buildBalanceHeroCard(CreatorStudioModel studio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Available Liquid Balance',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _hideBalance = !_hideBalance),
                    child: Icon(
                      _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (studio.pendingWithdrawals > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    '₹${studio.pendingWithdrawals.toStringAsFixed(0)} Pending',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hideBalance ? '••••••••' : _currencyFormat.format(studio.availableBalance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 16, color: AppColors.successGreen),
              const SizedBox(width: 4),
              Text(
                'Period Income: ${_currencyFormat.format(studio.periodEarnings)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successGreen),
              ),
              const SizedBox(width: 8),
              Text(
                '• Lifetime: ${_currencyFormat.format(studio.totalLifetimeEarnings)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final auth = AuthService.instance;
                if (auth.isGuest) {
                  AuthRequiredDialog.show(context, actionName: 'request payouts');
                  return;
                }
                if (!studio.isKycVerified) {
                  _openKycModal(context, studio);
                  return;
                }
                if (studio.availableBalance < 500) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Minimum withdrawal threshold is ₹500.00'),
                      backgroundColor: AppColors.rose,
                    ),
                  );
                  return;
                }
                _openWithdrawalModal(context, studio);
              },
              icon: Icon(
                studio.isKycVerified ? Icons.account_balance_outlined : Icons.lock_outline,
                size: 17,
              ),
              label: Text(
                studio.isKycVerified
                    ? (studio.availableBalance >= 500 ? 'Withdraw to Bank' : 'Minimum Withdrawal ₹500.00')
                    : 'Complete Bank KYC to Withdraw',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: studio.isKycVerified && studio.availableBalance >= 500
                    ? AppColors.primaryBlue
                    : Colors.grey.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Date Preset Rail ---
  Widget _buildDateFilterRail() {
    final presets = [
      {'id': 'all', 'label': 'All Time'},
      {'id': 'today', 'label': 'Today'},
      {'id': '7d', 'label': '7 Days'},
      {'id': 'this_month', 'label': 'This Month'},
      {'id': '30d', 'label': '30 Days'},
      {'id': 'custom', 'label': 'Custom Range'},
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = presets[index];
          final isSelected = _datePreset == p['id'];
          return ChoiceChip(
            label: Text(p['label']!),
            selected: isSelected,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            selectedColor: AppColors.primaryBlue,
            backgroundColor: Colors.white,
            side: BorderSide(color: isSelected ? AppColors.primaryBlue : AppColors.surfaceBorder),
            onSelected: (_) => _onDatePresetSelected(p['id']!),
          );
        },
      ),
    );
  }

  // --- Live KYC Status Banner ---
  Widget _buildKycStatusBanner(CreatorStudioModel studio) {
    if (studio.isKycVerified) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bank Account Linked & Verified',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${studio.kycBank} •••• ${studio.kycAccount.length > 4 ? studio.kycAccount.substring(studio.kycAccount.length - 4) : studio.kycAccount} (${studio.kycHolderName})',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryBlue),
              onPressed: () => _openKycModal(context, studio),
              tooltip: 'Update Bank Details',
            ),
          ],
        ),
      );
    }

    if (studio.kycRejectionReason.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KYC Rejected • Action Required',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.rose),
                  ),
                  Text(
                    studio.kycRejectionReason,
                    style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _openKycModal(context, studio),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Resubmit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (studio.isKycSubmitted) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KYC Verification In Progress',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Documents under admin review. Payouts unlock immediately upon approval.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.primaryBlue),
              onPressed: () => _openKycModal(context, studio),
              tooltip: 'View Submitted Details',
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primaryBlue, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank KYC Verification Needed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                Text(
                  'Link your bank account to unlock direct withdrawals & milestone rewards.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _openKycModal(context, studio),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Start KYC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Earnings Breakdown Cards ---
  Widget _buildEarningsBreakdownCards(CreatorStudioModel studio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Revenue Streams',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.military_tech_rounded, size: 22, color: AppColors.primaryBlue),
                    const SizedBox(height: 8),
                    const Text('Milestone Rewards', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      studio.silverRewardPaid ? '₹2,500.00' : '₹0.00',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      studio.silverRewardPaid ? 'Silver Tier Paid' : '${studio.totalApprovedVideos}/50 approved',
                      style: const TextStyle(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.card_giftcard_rounded, size: 22, color: AppColors.successGreen),
                    const SizedBox(height: 8),
                    const Text('Welcome Bonus', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(studio.welcomeCredit),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    const Text('Creator Incentive', style: TextStyle(fontSize: 10, color: AppColors.successGreen, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Type Filter Chip ---
  Widget _buildTypeChip(String label, String type) {
    final isSelected = _txTypeFilter == type;
    return GestureDetector(
      onTap: () => _onTxTypeChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
