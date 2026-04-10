import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QRPassButton extends StatefulWidget {
  const QRPassButton({super.key});

  @override
  State<QRPassButton> createState() => _QRPassButtonState();
}

class _QRPassButtonState extends State<QRPassButton> {
  String? _savedQRPath;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedQR();
  }

  Future<void> _loadSavedQR() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedQRPath = prefs.getString('local_qr_path');
    });
  }

  Future<void> _pickAndSaveQR() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String safePath = '${directory.path}/user_qr.png';
        
        final File newImage = await File(pickedFile.path).copy(safePath);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_qr_path', newImage.path);
        
        setState(() {
          _savedQRPath = newImage.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick QR: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showQRDialog() {
    if (_savedQRPath == null) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Mess QR',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(_savedQRPath!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('local_qr_path');
                        
                        try {
                          await File(_savedQRPath!).delete();
                        } catch(e) {}

                        setState(() {
                          _savedQRPath = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Delete'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        width: 24,
        height: 24,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    return IconButton(
      onPressed: () {
        if (_savedQRPath == null) {
          _pickAndSaveQR();
        } else {
          _showQRDialog();
        }
      },
      icon: Icon(
        Icons.qr_code_2,
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
      ),
    );
  }
}
