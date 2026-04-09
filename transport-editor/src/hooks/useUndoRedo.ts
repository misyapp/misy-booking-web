import { useEffect } from 'react';
import { useEditorStore } from '../store/editorStore';

export function useUndoRedo() {
  const undo = useEditorStore.temporal.getState().undo;
  const redo = useEditorStore.temporal.getState().redo;

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'z') {
        e.preventDefault();
        if (e.shiftKey) {
          redo();
        } else {
          undo();
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [undo, redo]);

  return { undo, redo };
}
