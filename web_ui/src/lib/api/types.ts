import type { components } from './types.gen';

type Schemas = components['schemas'];

export type Role = Schemas['Role'];
export type ApiErrorBody = Schemas['Error'];
export type LoginResponse = Schemas['LoginResponse'];
export type Session = Schemas['Session'];
export type Access = Schemas['Access'];
export type Action = Schemas['Action'];
export type ActionRequest = Schemas['ActionRequest'];
export type DispatchResult = Schemas['DispatchResult'];
export type LensAxis = Schemas['LensAxis'];
export type Projector = Schemas['Projector'];
export type Group = Schemas['Group'];
export type Config = Schemas['Config'];
export type ColumnId = Schemas['ColumnId'];
export type TableLayout = Schemas['TableLayout'];
export type Density = Schemas['Density'];
export type SnapshotEvent = Schemas['SnapshotEvent'];
export type ProjectEvent = Schemas['ProjectEvent'];
export type Alignment = Schemas['Alignment'];
export type AlignmentRole = Schemas['AlignmentRole'];
export type AlignmentPresetId = Schemas['AlignmentPresetId'];
export type PreviewStatus = Schemas['PreviewStatus'];
export type PreviewFrame = Schemas['PreviewFrame'];
export type PreShowRequest = Schemas['PreShowRequest'];
/** The table's columns: the app's catalogue plus the page's own Preview. */
export type TableColumn = ColumnId | 'preview';
export type AlignmentOp =
  | 'enter'
  | 'exit'
  | 'next'
  | 'prev'
  | 'focus'
  | 'neighbours'
  | 'diagonals'
  | 'showAll'
  | 'preset'
  | 'focusedPattern'
  | 'othersPattern';
