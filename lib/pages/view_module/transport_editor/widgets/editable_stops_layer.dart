import 'package:flutter/material.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:rider_ride_hailing_app/provider/transport_editor_provider.dart';

/// Couche d'édition des arrêts : markers draggables numérotés.
/// Tap = édition nom.
/// Long press = suppression.
class EditableStopsLayer extends StatelessWidget {
  final List<EditableStop> stops;
  final bool editable;
  final Color color;
  final void Function(int index, LatLng newPos)? onStopMoved;
  final void Function(int index)? onStopTapped;
  final void Function(int index)? onStopLongPressed;

  const EditableStopsLayer({
    super.key,
    required this.stops,
    this.editable = false,
    this.color = const Color(0xFFD32F2F),
    this.onStopMoved,
    this.onStopTapped,
    this.onStopLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DragMarkers(
      alignment: Alignment.topCenter,
      markers: [
        for (int i = 0; i < stops.length; i++)
          DragMarker(
            key: ValueKey('stop-$i'),
            point: stops[i].position,
            size: const Size(36, 46),
            alignment: Alignment.topCenter,
            builder: (ctx, pos, isDragging) {
              return _StopPin(
                number: i + 1,
                color: color,
                dragging: isDragging,
                label: stops[i].name,
              );
            },
            onDragEnd: editable
                ? (_, newPos) => onStopMoved?.call(i, newPos)
                : null,
            onTap: (_) => onStopTapped?.call(i),
            onLongPress: editable
                ? (_) => onStopLongPressed?.call(i)
                : null,
          ),
      ],
    );
  }
}

class _StopPin extends StatelessWidget {
  final int number;
  final Color color;
  final bool dragging;
  final String label;

  const _StopPin({
    required this.number,
    required this.color,
    required this.dragging,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final pinColor = dragging ? Colors.orange : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Pointe
        CustomPaint(
          size: const Size(10, 10),
          painter: _PinTipPainter(pinColor),
        ),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  _PinTipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTipPainter old) => old.color != color;
}

/// Panneau latéral listant les arrêts avec reorder + rename + delete.
class StopsListPanel extends StatelessWidget {
  final List<EditableStop> stops;
  final bool editable;
  final void Function(int oldIdx, int newIdx)? onReorder;
  final void Function(int index, String newName)? onRename;
  final void Function(int index)? onDelete;
  final void Function(int index)? onFocus;

  const StopsListPanel({
    super.key,
    required this.stops,
    this.editable = false,
    this.onReorder,
    this.onRename,
    this.onDelete,
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ReorderableListView.builder(
        buildDefaultDragHandles: editable,
        itemCount: stops.length,
        onReorder: (o, n) => onReorder?.call(o, n),
        itemBuilder: (ctx, i) {
          final s = stops[i];
          return ListTile(
            key: ValueKey('stop-tile-$i'),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFD32F2F),
              child: Text('${i + 1}',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${s.position.latitude.toStringAsFixed(5)}, '
              '${s.position.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            onTap: () => onFocus?.call(i),
            trailing: editable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Renommer',
                        onPressed: () async {
                          final name = await _promptRename(context, s.name);
                          if (name != null) onRename?.call(i, name);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        tooltip: 'Supprimer',
                        onPressed: () => onDelete?.call(i),
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<String?> _promptRename(BuildContext context, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer l\'arrêt'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
