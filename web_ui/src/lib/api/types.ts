import type { components } from './types.gen';

type Schemas = components['schemas'];

export type Role = Schemas['Role'];
export type ApiErrorBody = Schemas['Error'];
export type LoginResponse = Schemas['LoginResponse'];
export type Session = Schemas['Session'];
export type Projector = Schemas['Projector'];
export type Group = Schemas['Group'];
export type Config = Schemas['Config'];
export type ColumnId = Schemas['ColumnId'];
export type TableLayout = Schemas['TableLayout'];
export type Density = Schemas['Density'];
export type SnapshotEvent = Schemas['SnapshotEvent'];
export type ProjectEvent = Schemas['ProjectEvent'];
