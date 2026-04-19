import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';

/// Couche d'édition de polyligne : affiche la polyligne + handles draggables
/// à chaque vertex. Tap sur un handle de milieu de segment = insère un vertex.
/// Long press marker = supprime.
///
/// Note : en mode non-édition ([editable] = false), seule la polyligne est
/// affichée, sans handles.
class EditablePolylineLayer extends StatelessWidget {
  final List<LatLng> vertices;
  final Color color;
  final bool editable;
  final void Function(int index, LatLng newPos)? onVertexMoved;
  final void Function(int index)? onVertexRemoved;
  final void Function(int afterIndex, LatLng pos)? onVertexInserted;

  const EditablePolylineLayer({
    super.key,
    required this.vertices,
    this.color = const Color(0xFF1565C0),
    this.editable = false,
    this.onVertexMoved,
    this.onVertexRemoved,
    this.onVertexInserted,
  });

  @override
  Widget build(BuildContext context) {
    // Décimation visuelle des handles si trop de vertices (perf)
    final handlesEveryN = vertices.length > 200 ? 3 : 1;

    return Stack(children: [
      PolylineLayer(
        polylines: [
          Polyline(
            points: vertices,
            strokeWidth: 5.0,
            color: color,
            borderStrokeWidth: 1.5,
            borderColor: Colors.white,
          ),
        ],
      ),
      if (editable && vertices.isNotEmpty)
        DragMarkers(
          markers: [
            for (int i = 0; i < vertices.length; i++)
              if (i % handlesEveryN == 0 || i == vertices.length - 1)
                _vertexMarker(i),
            for (int i = 0; i < vertices.length - 1; i++)
              _midpointMarker(i),
          ],
        ),
    ]);
  }

  DragMarker _vertexMarker(int index) {
    return DragMarker(
      key: ValueKey('vx-$index'),
      point: vertices[index],
      size: const Size(22, 22),
      builder: (ctx, pos, isDragging) {
        return Container(
          decoration: BoxDecoration(
            color: isDragging ? Colors.orange : color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 3,
              ),
            ],
          ),
        );
      },
      onDragEnd: (_, newPos) => onVertexMoved?.call(index, newPos),
      onLongPress: (_) => onVertexRemoved?.call(index),
    );
  }

  DragMarker _midpointMarker(int index) {
    final a = vertices[index];
    final b = vertices[index + 1];
    final mid = LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
    return DragMarker(
      key: ValueKey('mid-$index'),
      point: mid,
      size: const Size(14, 14),
      builder: (ctx, pos, isDragging) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(Icons.add, size: 10, color: color),
        );
      },
      // Tap ajoute un vertex à cette position milieu
      onTap: (pos) => onVertexInserted?.call(index, pos),
      // Drag ajoute et déplace en même temps
      onDragEnd: (_, newPos) => onVertexInserted?.call(index, newPos),
    );
  }
}
