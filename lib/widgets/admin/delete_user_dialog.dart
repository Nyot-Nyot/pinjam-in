import 'package:flutter/material.dart';

/// Reusable dialog for confirming user deletion
/// Supports both soft delete (deactivate) and hard delete (permanent)
class DeleteUserDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final int itemsCount;

  const DeleteUserDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.itemsCount,
  });

  @override
  State<DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends State<DeleteUserDialog> {
  bool _hardDelete = false;
  bool _confirmChecked = false;
  final _reasonController = TextEditingController();
  bool _hasReason = false;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(_onReasonChanged);
  }

  void _onReasonChanged() {
    setState(() {
      _hasReason = _reasonController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _reasonController.removeListener(_onReasonChanged);
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: _hardDelete ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 12),
          Text(_hardDelete ? 'Permanent Delete' : 'Deactivate User'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.userEmail, style: theme.textTheme.bodySmall),
                  if (widget.itemsCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.itemsCount} items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delete type toggle
            SwitchListTile(
              title: const Text('Permanent Delete (Hard Delete)'),
              subtitle: Text(
                _hardDelete
                    ? 'User and all items will be permanently removed'
                    : 'User will be deactivated (can be reactivated later)',
                style: TextStyle(
                  color: _hardDelete ? Colors.red : null,
                  fontSize: 12,
                ),
              ),
              value: _hardDelete,
              onChanged: (value) {
                setState(() {
                  _hardDelete = value;
                  _confirmChecked = false; // Reset confirmation
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),

            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hardDelete
                    ? Colors.red.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _hardDelete ? Colors.red : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _hardDelete ? Icons.delete_forever : Icons.info_outline,
                    size: 20,
                    color: _hardDelete ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hardDelete
                          ? 'This action cannot be undone! All user data and ${widget.itemsCount} items will be permanently deleted.'
                          : 'User will be deactivated and cannot login. Items will be preserved. You can reactivate the user later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hardDelete
                            ? Colors.red[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Reason field
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText:
                    'Reason ${_hardDelete ? '(required)' : '(optional)'}',
                hintText:
                    'Why are you ${_hardDelete ? 'deleting' : 'deactivating'} this user?',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              maxLength: 200,
            ),

            const SizedBox(height: 8),

            // Confirmation checkbox
            CheckboxListTile(
              title: Text(
                'I understand the consequences',
                style: theme.textTheme.bodySmall,
              ),
              value: _confirmChecked,
              onChanged: (value) {
                setState(() {
                  _confirmChecked = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirmChecked && (!_hardDelete || _hasReason)
              ? () {
                  Navigator.pop(context, {
                    'hardDelete': _hardDelete,
                    'reason': _reasonController.text.trim(),
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _hardDelete ? Colors.red : Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: Text(_hardDelete ? 'Delete Permanently' : 'Deactivate'),
        ),
      ],
    );
  }
}
