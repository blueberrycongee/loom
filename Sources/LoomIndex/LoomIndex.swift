// LoomIndex — indexing pipeline: folder source → Vision feature-print →
// Core Image color → SQLite store → thumbnail cache.
//
// See Indexer.swift for the orchestrator. Individual stages live in their own
// files so each is testable and swappable.

import Foundation

public enum LoomIndex {}
