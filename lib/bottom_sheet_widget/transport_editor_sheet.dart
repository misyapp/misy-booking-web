import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/models/transport_contribution.dart';
import 'package:rider_ride_hailing_app/services/transport_contribution_service.dart';

/// Bottom sheet pour éditer/signaler une ligne de transport
class TransportEditorSheet extends StatefulWidget {
  final String lineNumber;
  final LatLng initialLocation;
  final Function(EditData) onEditConfirmed;

  const TransportEditorSheet({
    super.key,
    required this.lineNumber,
    required this.initialLocation,
    required this.onEditConfirmed,
  });

  @override
  State<TransportEditorSheet> createState() => _TransportEditorSheetState();
}

class _TransportEditorSheetState extends State<TransportEditorSheet> {
  EditAction _selectedAction = EditAction.add_stop;
  final TextEditingController _stopNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  LatLng? _markerPosition;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _markerPosition = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.edit_location_alt, color: MyColors.coralPink),
                const SizedBox(width: 12),
                Text(
                  'Éditer la ligne ${widget.lineNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins-SemiBold',
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type d'action
                  Text(
                    'Type de modification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActionSelector(),

                  const SizedBox(height: 20),

                  // Champs conditionnels
                  if (_selectedAction == EditAction.add_stop ||
                      _selectedAction == EditAction.move_stop) ...[
                    TextField(
                      controller: _stopNameController,
                      decoration: InputDecoration(
                        labelText: 'Nom de l\'arret',
                        hintText: 'Ex: Shoprite Analakely',
                        prefixIcon: const Icon(Icons.place),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Deplacez le marqueur sur la carte pour positionner l\'arret',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Description
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (obligatoire)',
                      hintText: 'Decrivez la modification en detail...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Coordonnees GPS
                  if (_markerPosition != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'GPS: ${_markerPosition!.latitude.toStringAsFixed(6)}, '
                            '${_markerPosition!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Boutons d'action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitContribution,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.coralPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Envoyer',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionChip(
          action: EditAction.add_stop,
          icon: Icons.add_location,
          label: 'Ajouter arret',
        ),
        _buildActionChip(
          action: EditAction.move_stop,
          icon: Icons.open_with,
          label: 'Deplacer arret',
        ),
        _buildActionChip(
          action: EditAction.delete_stop,
          icon: Icons.remove_circle_outline,
          label: 'Supprimer arret',
        ),
        _buildActionChip(
          action: EditAction.modify_route,
          icon: Icons.edit_road,
          label: 'Modifier trace',
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required EditAction action,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedAction == action;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() => _selectedAction = action);
      },
      backgroundColor: Colors.grey[100],
      selectedColor: MyColors.coralPink.withValues(alpha: 0.2),
      checkmarkColor: MyColors.coralPink,
    );
  }

  Future<void> _submitContribution() async {
    // Validation
    if (_descriptionController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description trop courte (min 10 caracteres)'),
        ),
      );
      return;
    }

    if ((_selectedAction == EditAction.add_stop ||
            _selectedAction == EditAction.move_stop) &&
        _stopNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez indiquer le nom de l\'arret'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final editData = EditData(
      action: _selectedAction,
      stopName: _stopNameController.text.trim().isNotEmpty
          ? _stopNameController.text.trim()
          : null,
      newCoordinates: _markerPosition,
    );

    final success = await TransportContributionService.submitContribution(
      lineNumber: widget.lineNumber,
      contributionType: ContributionType.stop_edit,
      description: _descriptionController.text.trim(),
      location: _markerPosition!,
      editData: editData,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      widget.onEditConfirmed(editData);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contribution envoyee ! Merci.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'envoi. Etes-vous connecte ?'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
