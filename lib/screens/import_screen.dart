import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:csv/csv.dart';

import '../data/db_helper.dart';
import '../models/phone_number.dart';
import 'call_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final DbHelper _db = DbHelper();
  bool _isLoading = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Import phone numbers from Excel or CSV files',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supported Formats:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Phone Numbers only (Column A)'),
                  const Text('2. Name and Phone Numbers (Column A: Name, Column B: Phone)'),
                  const Text('3. Phone Numbers and Name (Column A: Phone, Column B: Name)'),
                  const SizedBox(height: 8),
                  const Text(
                    'Note: Headers are automatically detected and skipped.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _importExcel,
              icon: const Icon(Icons.table_chart),
              label: const Text('Import Excel File'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _importCSV,
              icon: const Icon(Icons.description),
              label: const Text('Import CSV File'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _clearAllData,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear All Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _importExcel() async {
    setState(() {
      _isLoading = true;
      _status = '';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        final picked = result.files.single;
        // Prefer in-memory bytes in release where direct file access may fail
        final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
        final excelFile = excel.Excel.decodeBytes(bytes);
        
        final numbers = <PhoneNumber>[];
        int skippedRows = 0;
        
        // Always use first sheet for simplicity and reliability in release
        if (excelFile.tables.isNotEmpty) {
          final String firstKey = excelFile.tables.keys.first;
          final sheet = excelFile.tables[firstKey]!;

          // Detect header by checking first row for any non-digit characters
          final int startRowIndex;
          if (sheet.rows.isNotEmpty) {
            final headerCell = sheet.rows[0].isNotEmpty ? sheet.rows[0][0] : null;
            final headerText = _extractStringFromCell(headerCell) ?? '';
            final looksLikeHeader = headerText.toLowerCase().contains('phone') || headerText.toLowerCase().contains('name');
            startRowIndex = looksLikeHeader ? 1 : 0;
          } else {
            startRowIndex = 0;
          }

          for (int i = startRowIndex; i < sheet.maxRows; i++) {
            final row = sheet.rows[i];
            if (row.isNotEmpty) {
              try {
                // Extract phone number and name from Excel cells
                String? phoneNumber;
                String? name;
                
                // Try different column combinations
                if (row.length >= 1 && row[0] != null) {
                  phoneNumber = _extractStringFromCell(row[0]);
                }
                
                if (row.length >= 2 && row[1] != null) {
                  final secondCell = _extractStringFromCell(row[1]);
                  // Check if second cell looks like a phone number
                  if (_isPhoneNumber(secondCell)) {
                    phoneNumber = secondCell;
                  } else {
                    name = secondCell;
                  }
                }
                
                // Validate and clean phone number
                if (kDebugMode) {
                  print('DEBUG: Row $i - Raw phoneNumber: "$phoneNumber", name: "$name"');
                }
                if (phoneNumber != null && phoneNumber.isNotEmpty) {
                  // Clean the phone number and accept if it has reasonable length
                  final cleanedNumber = _cleanPhoneNumber(phoneNumber);
                  final valid = cleanedNumber.isNotEmpty && cleanedNumber.replaceAll(RegExp(r'[^\d]'), '').length >= 5;
                  if (valid) {
                    numbers.add(PhoneNumber(
                      number: cleanedNumber,
                      name: name?.isNotEmpty == true ? name : null,
                    ));
                    if (kDebugMode) {
                      print('DEBUG: Row $i - ACCEPTED: "$cleanedNumber"');
                    }
                  } else {
                    if (kDebugMode) {
                      print('DEBUG: Row $i - REJECTED (length): "$cleanedNumber"');
                    }
                    skippedRows++;
                  }
                } else {
                  if (kDebugMode) {
                    print('DEBUG: Row $i - REJECTED: phoneNumber is null or empty');
                  }
                  skippedRows++;
                }
              } catch (e) {
                // Skip rows that cause errors
                skippedRows++;
                if (kDebugMode) {
                  print('Error processing row $i: $e');
                }
              }
            }
          }
        }

        if (kDebugMode) {
          print('DEBUG: About to save ${numbers.length} numbers to database');
          for (int i = 0; i < numbers.length; i++) {
            print('DEBUG: Saving number $i: ${numbers[i].number} (name: ${numbers[i].name})');
          }
        }
        
        await _db.replaceAllNumbers(numbers);
        
        // Verify the data was saved
        final savedNumbers = await _db.fetchAllNumbers();
        if (kDebugMode) {
          print('DEBUG: Verification - ${savedNumbers.length} numbers found in database after save');
        }
        
        setState(() {
          String statusMessage = 'Successfully imported ${numbers.length} numbers from Excel file. All previous data has been replaced.';
          if (skippedRows > 0) {
            statusMessage += ' (Skipped $skippedRows invalid rows)';
          }
          _status = statusMessage;
        });
        
        // Auto-navigate to call screen after successful import
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(); // Go back to home
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CallScreen()),
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error importing Excel file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _extractStringFromCell(dynamic cell) {
    if (kDebugMode) {
      print('DEBUG: _extractStringFromCell - cell type: ${cell.runtimeType}, value: $cell');
    }
    if (cell == null) return null;

    // If this looks like an Excel cell wrapper, try to read its `.value` first
    try {
      final dynamic maybeValue = (cell as dynamic).value;
      if (maybeValue != null && maybeValue != cell) {
        final inner = _extractStringFromCell(maybeValue);
        if (inner != null && inner.isNotEmpty) {
          return inner;
        }
      }
    } catch (_) {
      // ignore when object doesn't expose `.value`
    }
    
    // Handle different Excel cell types
    if (cell is String) {
      final result = cell.trim();
      if (kDebugMode) {
        print('DEBUG: _extractStringFromCell - String result: "$result"');
      }
      return result;
    } else if (cell is int) {
      final result = cell.toString();
      if (kDebugMode) {
        print('DEBUG: _extractStringFromCell - Int result: "$result"');
      }
      return result;
    } else if (cell is double) {
      // Avoid scientific notation; treat as whole number when appropriate
      final result = (cell % 1 == 0)
          ? cell.toStringAsFixed(0)
          : cell.toString();
      if (kDebugMode) {
        print('DEBUG: _extractStringFromCell - Double result: "$result"');
      }
      return result;
    } else if (cell is excel.CellValue) {
      // Handle Excel CellValue objects using the correct API
      if (cell is excel.TextCellValue) {
        // TextCellValue contains a TextSpan, extract the text
        final textSpan = cell.value;
        if (textSpan is TextSpan) {
          final result = textSpan.text?.trim();
          if (kDebugMode) {
            print('DEBUG: _extractStringFromCell - TextCellValue (TextSpan) result: "$result"');
          }
          return result;
        }
        final result = textSpan.toString().trim();
        if (kDebugMode) {
          print('DEBUG: _extractStringFromCell - TextCellValue result: "$result"');
        }
        return result;
      } else if (cell is excel.IntCellValue) {
        final result = cell.value.toString();
        if (kDebugMode) {
          print('DEBUG: _extractStringFromCell - IntCellValue result: "$result"');
        }
        return result;
      } else if (cell is excel.DoubleCellValue) {
        final value = cell.value;
        final result = (value % 1 == 0)
            ? value.toStringAsFixed(0)
            : value.toString();
        if (kDebugMode) {
          print('DEBUG: _extractStringFromCell - DoubleCellValue result: "$result"');
        }
        return result;
      } else if (cell is excel.BoolCellValue) {
        final result = cell.value.toString();
        if (kDebugMode) {
          print('DEBUG: _extractStringFromCell - BoolCellValue result: "$result"');
        }
        return result;
      } else if (cell is excel.DateTimeCellValue) {
        // DateTimeCellValue doesn't have a value property, use toString
        final result = cell.toString();
        if (kDebugMode) {
          print('DEBUG: _extractStringFromCell - DateTimeCellValue result: "$result"');
        }
        return result;
      } else if (cell is excel.FormulaCellValue) {
        // FormulaCellValue doesn't have a value property, use toString
        final result = cell.toString();
        if (kDebugMode) {
          print('DEBUG: _extractStringFromCell - FormulaCellValue result: "$result"');
        }
        return result;
      } else {
        // For other CellValue types, try to convert to string
        try {
          final result = cell.toString().trim();
          if (kDebugMode) {
            print('DEBUG: _extractStringFromCell - Other CellValue result: "$result"');
          }
          return result;
        } catch (e) {
          if (kDebugMode) {
            print('DEBUG: _extractStringFromCell - Error converting CellValue: $e');
          }
          return null;
        }
      }
    } else {
      // For other types, try to convert to string
      try {
        final str = cell.toString();
        // Check for common "not a number" or error indicators
        if (str.toLowerCase().contains('nan') || 
            str.toLowerCase().contains('not a number') ||
            str.toLowerCase().contains('error') ||
            str.toLowerCase().contains('#value!') ||
            str.toLowerCase().contains('#div/0!') ||
            str.toLowerCase().contains('#ref!') ||
            str.toLowerCase().contains('#name?') ||
            str.toLowerCase().contains('#null!') ||
            str.toLowerCase().contains('#num!')) {
          return null; // Skip invalid values
        }
        
        if (str.isNotEmpty) {
          // Prefer the longest digit run to avoid scientific notation issues
          final digitRuns = RegExp(r'\d+').allMatches(str).map((m) => m.group(0)!).toList();
          if (digitRuns.isNotEmpty) {
            digitRuns.sort((a, b) => b.length.compareTo(a.length));
            return digitRuns.first;
          }
          return str.trim();
        }
      } catch (e) {
        // If conversion fails, return null
        return null;
      }
    }
    return null;
  }

  bool _isPhoneNumber(String? text) {
    if (text == null || text.isEmpty) return false;
    
    // Remove common phone number characters and check if mostly digits
    final cleaned = text.replaceAll(RegExp(r'[\+\-\s\(\)]'), '');
    final digitCount = cleaned.split('').where((c) => RegExp(r'\d').hasMatch(c)).length;
    final totalLength = cleaned.length;
    
    if (kDebugMode) {
      print('DEBUG: _isPhoneNumber - text: "$text", cleaned: "$cleaned", digitCount: $digitCount, totalLength: $totalLength');
    }
    
    // Consider it a phone number if:
    // 1. It has at least 5 digits (for short numbers)
    // 2. At least 70% of the characters are digits (to handle numbers with some formatting)
    // 3. It's not just a single digit or very short
    final isValid = digitCount >= 5 && 
                   digitCount >= (totalLength * 0.7) && 
                   totalLength >= 3;
    
    if (kDebugMode) {
      print('DEBUG: _isPhoneNumber - isValid: $isValid');
    }
    return isValid;
  }

  String _cleanPhoneNumber(String phoneNumber) {
    if (kDebugMode) {
      print('DEBUG: _cleanPhoneNumber - input: "$phoneNumber"');
    }
    
    // Remove all non-digit characters except + at the beginning
    String cleaned = phoneNumber.trim();
    
    // Remove common prefixes and suffixes that might be in Excel
    cleaned = cleaned.replaceAll(RegExp(r'^tel:', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^phone:', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^call:', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^mobile:', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^cell:', caseSensitive: false), '');
    
    // Remove extra whitespace and special characters except + at start
    if (cleaned.startsWith('+')) {
      cleaned = '+' + cleaned.substring(1).replaceAll(RegExp(r'[^\d]'), '');
    } else {
      cleaned = cleaned.replaceAll(RegExp(r'[^\d]'), '');
    }
    
    if (kDebugMode) {
      print('DEBUG: _cleanPhoneNumber - output: "$cleaned"');
    }
    return cleaned;
  }

  Future<void> _importCSV() async {
    setState(() {
      _isLoading = true;
      _status = '';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final picked = result.files.single;
        final csvString = picked.bytes != null
            ? String.fromCharCodes(picked.bytes!)
            : await File(picked.path!).readAsString();
        final csvData = const CsvToListConverter().convert(csvString);
        
        final numbers = <PhoneNumber>[];
        // Skip header row (row 0)
        for (int i = 1; i < csvData.length; i++) {
          final row = csvData[i];
          if (row.isNotEmpty) {
            String? phoneNumber;
            String? name;
            
            // Try different column combinations
            if (row.length >= 1) {
              phoneNumber = row[0]?.toString().trim();
            }
            
            if (row.length >= 2) {
              final secondCell = row[1]?.toString().trim();
              // Check if second cell looks like a phone number
              if (_isPhoneNumber(secondCell)) {
                phoneNumber = secondCell;
              } else {
                name = secondCell;
              }
            }
            
            // If we have a phone number, clean and add it to the list
            if (phoneNumber != null && phoneNumber.isNotEmpty) {
              final cleaned = _cleanPhoneNumber(phoneNumber);
              if (cleaned.replaceAll(RegExp(r'[^\d]'), '').length >= 5) {
                numbers.add(PhoneNumber(
                  number: cleaned,
                  name: name?.isNotEmpty == true ? name : null,
                ));
              } else if (kDebugMode) {
                print('DEBUG CSV: REJECTED (length): "$cleaned"');
              }
            }
          }
        }

        await _db.replaceAllNumbers(numbers);
        
        setState(() {
          _status = 'Successfully imported ${numbers.length} numbers from CSV file. All previous data has been replaced.';
        });
        
        // Auto-navigate to call screen after successful import
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(); // Go back to home
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CallScreen()),
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error importing CSV file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all phone numbers? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _status = '';
      });

      try {
        await _db.clearAllNumbers();
        setState(() {
          _status = 'All phone numbers have been cleared from the database.';
        });
      } catch (e) {
        setState(() {
          _status = 'Error clearing data: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
