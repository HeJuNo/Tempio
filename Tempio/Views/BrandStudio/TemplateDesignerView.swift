import SwiftUI

/// Gesture-based template canvas (step 2 of the hybrid designer).
/// - Tap a zone to select it, drag to move, drag the corner handle or pinch to resize.
/// - Multi-step undo / redo of every layout and property change.
struct TemplateDesignerView: View {
    @EnvironmentObject private var store: TemplateStore
    let setID: UUID
    let templateID: UUID

    @State private var template: PostTemplate?
    @State private var selectedZoneID: UUID?
    @State private var previewSize: InstagramSize = .square
    @State private var undoStack: [PostTemplate] = []
    @State private var redoStack: [PostTemplate] = []
    @State private var gestureStartRect: CGRect?
    @State private var lastUndoPush = Date.distantPast
    @State private var saveTask: Task<Void, Never>?
    @State private var showPresetPicker = false
    @State private var showSafeZones = true

    var body: some View {
        Group {
            if let set = store.set(id: setID), let template {
                content(set: set, template: template)
            } else {
                ProgressView()
            }
        }
        .onAppear(perform: load)
        .onDisappear { saveNow() }
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(set: TemplateSet, template: PostTemplate) -> some View {
        let editable = store.canEdit(set)
        VStack(spacing: 0) {
            sizeTabs
            canvas(set: set, template: template, editable: editable)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let zoneBinding = selectedZoneBinding {
                        ZoneInspector(zone: zoneBinding, set: set,
                                      fontNames: store.availableFontNames(for: set),
                                      onLayerUp: { moveLayer(by: 1) },
                                      onLayerDown: { moveLayer(by: -1) },
                                      onDuplicate: duplicateZone,
                                      onDelete: deleteZone)
                    } else {
                        templateSettings(set: set)
                    }
                }
                .padding()
                .disabled(!editable)
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(undoStack.isEmpty || !editable)
                Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(redoStack.isEmpty || !editable)
                Menu {
                    ForEach(TemplateZone.ZoneType.allCases) { type in
                        Button { addZone(type, set: set) } label: { Label("Add \(type.displayName)", systemImage: type.systemImage) }
                    }
                    Divider()
                    Button { showPresetPicker = true } label: { Label("Apply Preset Layout…", systemImage: "square.grid.2x2") }
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .disabled(!editable)
            }
        }
        .confirmationDialog("Apply preset layout", isPresented: $showPresetPicker, titleVisibility: .visible) {
            ForEach(PresetLayout.allCases) { p in
                Button(p.displayName) { applyPreset(p, set: set) }
            }
        } message: {
            Text("Replaces all zones. You can undo this.")
        }
    }

    private var sizeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InstagramSize.allCases) { size in
                    Button { previewSize = size } label: {
                        VStack(spacing: 2) {
                            Text(size.displayName).font(.caption.bold())
                            Text(size.ratioLabel).font(.caption2)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(previewSize == size ? Color.accentColor : Color(.secondarySystemBackground)))
                        .foregroundStyle(previewSize == size ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func canvas(set: TemplateSet, template: PostTemplate, editable: Bool) -> some View {
        GeometryReader { geo in
            let available = CGSize(width: geo.size.width - 32, height: geo.size.height)
            let ratio = previewSize.aspectRatio
            let canvasSize: CGSize = available.width / available.height > ratio
                ? CGSize(width: available.height * ratio, height: available.height)
                : CGSize(width: available.width, height: available.width / ratio)

            ZStack(alignment: .topLeading) {
                Image(uiImage: PostImageRenderer.render(template: template, filledTexts: [:], filledImages: [:],
                                                        set: set, store: store, size: previewSize,
                                                        scale: 0.4, showPlaceholders: true))
                    .resizable()
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .onTapGesture { selectedZoneID = nil }

                if previewSize == .story && showSafeZones {
                    safeZoneOverlay(canvasSize: canvasSize)
                }

                ForEach(template.sortedZones) { zone in
                    zoneOverlay(zone, canvasSize: canvasSize, editable: editable)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipped()
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func safeZoneOverlay(canvasSize: CGSize) -> some View {
        let top = previewSize.unsafeTopFraction * canvasSize.height
        let bottom = previewSize.unsafeBottomFraction * canvasSize.height
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.red.opacity(0.18)).frame(width: canvasSize.width, height: top)
                .overlay(Text("Instagram UI").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
            Rectangle().fill(Color.red.opacity(0.18)).frame(width: canvasSize.width, height: bottom)
                .overlay(Text("Reply bar").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                .offset(y: canvasSize.height - bottom)
        }
        .allowsHitTesting(false)
    }

    private func zoneOverlay(_ zone: TemplateZone, canvasSize: CGSize, editable: Bool) -> some View {
        let isSelected = zone.id == selectedZoneID
        let frame = CGRect(x: zone.normalizedRect.minX * canvasSize.width,
                           y: zone.normalizedRect.minY * canvasSize.height,
                           width: zone.normalizedRect.width * canvasSize.width,
                           height: zone.normalizedRect.height * canvasSize.height)
        let canInteract = editable && !zone.isLocked

        return ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .fill(Color.white.opacity(0.001)) // hit area
                .overlay(
                    Rectangle().stroke(isSelected ? Color.accentColor : Color.white.opacity(0.5),
                                       style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: isSelected ? [] : [4, 3]))
                )
                .overlay(alignment: .topLeading) {
                    if isSelected {
                        HStack(spacing: 3) {
                            Image(systemName: zone.zoneType.systemImage)
                            Text(zone.name)
                            if zone.isLocked { Image(systemName: "lock.fill") }
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .offset(y: frame.minY > 14 ? -14 : 0)
                    }
                }
            if isSelected && canInteract {
                Circle()
                    .fill(Color.accentColor)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .frame(width: 22, height: 22)
                    .offset(x: 11, y: 11)
                    .gesture(resizeGesture(zone: zone, canvasSize: canvasSize))
            }
        }
        .frame(width: max(frame.width, 1), height: max(frame.height, 1))
        .offset(x: frame.minX, y: frame.minY)
        .onTapGesture { selectedZoneID = zone.id }
        .gesture(canInteract ? moveGesture(zone: zone, canvasSize: canvasSize) : nil)
        .simultaneousGesture(canInteract && isSelected ? pinchGesture(zone: zone) : nil)
    }

    // MARK: - Gestures

    private func moveGesture(zone: TemplateZone, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if gestureStartRect == nil {
                    pushUndo(force: true)
                    gestureStartRect = zone.normalizedRect
                    selectedZoneID = zone.id
                }
                guard let start = gestureStartRect else { return }
                updateZone(zone.id, recordUndo: false) { z in
                    z.normalizedRect.origin.x = start.minX + value.translation.width / canvasSize.width
                    z.normalizedRect.origin.y = start.minY + value.translation.height / canvasSize.height
                    z.clampRect()
                }
            }
            .onEnded { _ in gestureStartRect = nil }
    }

    private func resizeGesture(zone: TemplateZone, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if gestureStartRect == nil {
                    pushUndo(force: true)
                    gestureStartRect = zone.normalizedRect
                }
                guard let start = gestureStartRect else { return }
                updateZone(zone.id, recordUndo: false) { z in
                    z.normalizedRect.size.width = start.width + value.translation.width / canvasSize.width
                    z.normalizedRect.size.height = start.height + value.translation.height / canvasSize.height
                    z.clampRect()
                }
            }
            .onEnded { _ in gestureStartRect = nil }
    }

    private func pinchGesture(zone: TemplateZone) -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if gestureStartRect == nil {
                    pushUndo(force: true)
                    gestureStartRect = zone.normalizedRect
                }
                guard let start = gestureStartRect else { return }
                updateZone(zone.id, recordUndo: false) { z in
                    let w = start.width * scale, h = start.height * scale
                    z.normalizedRect = CGRect(x: start.midX - w / 2, y: start.midY - h / 2, width: w, height: h)
                    z.clampRect()
                }
            }
            .onEnded { _ in gestureStartRect = nil }
    }

    // MARK: - Template settings (no zone selected)

    @ViewBuilder
    private func templateSettings(set: TemplateSet) -> some View {
        Text("Template").font(.headline)
        Text("Tap a zone on the canvas to edit it. Drag to move, use the corner handle or pinch to resize.")
            .font(.caption).foregroundStyle(.secondary)

        LabeledContent("Name") {
            TextField("Name", text: templateBinding(\.name)).multilineTextAlignment(.trailing)
        }
        Picker("Base size", selection: templateBinding(\.instagramSize)) {
            ForEach(InstagramSize.allCases) { Text("\($0.displayName) \($0.dimensionLabel)").tag($0) }
        }
        Picker("Export format", selection: templateBinding(\.exportFormat)) {
            Text("JPEG").tag(PostTemplate.ExportFormat.jpeg)
            Text("PNG").tag(PostTemplate.ExportFormat.png)
        }
        .pickerStyle(.segmented)
        if template?.exportFormat == .jpeg {
            VStack(alignment: .leading) {
                Text("JPEG quality: \(Int((template?.jpegQuality ?? 0.9) * 100)) %").font(.subheadline)
                Slider(value: templateBinding(\.jpegQuality), in: 0.5...1.0, step: 0.01)
            }
        }
        if previewSize == .story {
            Toggle("Show Story safe zones", isOn: $showSafeZones)
        }

        Text("Zones").font(.headline).padding(.top, 8)
        ForEach(Array((template?.sortedZones ?? []).reversed())) { zone in
            Button { selectedZoneID = zone.id } label: {
                HStack {
                    Image(systemName: zone.zoneType.systemImage).frame(width: 24)
                    Text(zone.name)
                    Spacer()
                    if zone.zoneType == .text { Text(zone.textSlotType.kindName).font(.caption).foregroundStyle(.secondary) }
                    if zone.zoneType == .image { Text(zone.imageSlotType == .auto ? "Auto" : "Manual").font(.caption).foregroundStyle(.secondary) }
                    if zone.isLocked { Image(systemName: "lock.fill").font(.caption) }
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            Divider()
        }
    }

    private func templateBinding<T>(_ keyPath: WritableKeyPath<PostTemplate, T>) -> Binding<T> {
        Binding(
            get: { template![keyPath: keyPath] },
            set: { newValue in
                pushUndo(force: false)
                template?[keyPath: keyPath] = newValue
                scheduleSave()
            }
        )
    }

    // MARK: - Zone editing

    private var selectedZoneBinding: Binding<TemplateZone>? {
        guard let id = selectedZoneID, let t = template, t.zones.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.template?.zones.first(where: { $0.id == id }) ?? t.zones[0] },
            set: { newValue in
                updateZone(id, recordUndo: true) { $0 = newValue }
            }
        )
    }

    private func updateZone(_ id: UUID, recordUndo: Bool, _ change: (inout TemplateZone) -> Void) {
        guard var t = template, let i = t.zones.firstIndex(where: { $0.id == id }) else { return }
        if recordUndo { pushUndo(force: false) }
        change(&t.zones[i])
        template = t
        scheduleSave()
    }

    private func addZone(_ type: TemplateZone.ZoneType, set: TemplateSet) {
        guard var t = template else { return }
        pushUndo(force: true)
        let kit = set.brandKit
        var zone = TemplateZone(name: type.displayName, zoneType: type,
                                normalizedRect: CGRect(x: 0.25, y: 0.35, width: 0.5, height: type == .text ? 0.12 : 0.3),
                                layerOrder: (t.zones.map(\.layerOrder).max() ?? -1) + 1)
        switch type {
        case .text:
            zone.fontName = kit.bodyFont.fontName
            zone.fontSize = kit.bodyFont.size
            zone.fontWeight = kit.bodyFont.weight
            zone.placeholder = "Text"
        case .shape:
            zone.backgroundColorHex = kit.primaryColorHex
        case .logo:
            zone.normalizedRect = CGRect(x: 0.8, y: 0.05, width: 0.15, height: 0.12)
        case .image:
            zone.imageSlotType = .manual
        }
        t.zones.append(zone)
        template = t
        selectedZoneID = zone.id
        scheduleSave()
    }

    private func duplicateZone() {
        guard var t = template, let id = selectedZoneID, let z = t.zones.first(where: { $0.id == id }) else { return }
        pushUndo(force: true)
        var copy = z
        copy.id = UUID()
        copy.name = "\(z.name) Copy"
        copy.normalizedRect = z.normalizedRect.offsetBy(dx: 0.03, dy: 0.03)
        copy.clampRect()
        copy.layerOrder = (t.zones.map(\.layerOrder).max() ?? 0) + 1
        t.zones.append(copy)
        template = t
        selectedZoneID = copy.id
        scheduleSave()
    }

    private func deleteZone() {
        guard var t = template, let id = selectedZoneID else { return }
        pushUndo(force: true)
        t.zones.removeAll { $0.id == id }
        t.normalizeLayers()
        template = t
        selectedZoneID = nil
        scheduleSave()
    }

    /// +1 = bring forward, -1 = send backward
    private func moveLayer(by delta: Int) {
        guard var t = template, let id = selectedZoneID else { return }
        var ordered = t.sortedZones
        guard let i = ordered.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard j >= 0, j < ordered.count else { return }
        pushUndo(force: true)
        ordered.swapAt(i, j)
        for (index, zone) in ordered.enumerated() {
            if let k = t.zones.firstIndex(where: { $0.id == zone.id }) { t.zones[k].layerOrder = index }
        }
        template = t
        scheduleSave()
    }

    private func applyPreset(_ preset: PresetLayout, set: TemplateSet) {
        guard var t = template else { return }
        pushUndo(force: true)
        t.zones = preset.makeZones(brandKit: set.brandKit)
        template = t
        selectedZoneID = nil
        scheduleSave()
    }

    // MARK: - Undo / Redo

    /// Records the current state. Non-forced pushes are coalesced (e.g. typing) to one step per second.
    private func pushUndo(force: Bool) {
        guard let t = template else { return }
        if !force && Date().timeIntervalSince(lastUndoPush) < 1.0 { return }
        undoStack.append(t)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        lastUndoPush = Date()
    }

    private func undo() {
        guard let previous = undoStack.popLast(), let current = template else { return }
        redoStack.append(current)
        template = previous
        if let id = selectedZoneID, !previous.zones.contains(where: { $0.id == id }) { selectedZoneID = nil }
        lastUndoPush = .distantPast
        scheduleSave()
    }

    private func redo() {
        guard let next = redoStack.popLast(), let current = template else { return }
        undoStack.append(current)
        template = next
        lastUndoPush = .distantPast
        scheduleSave()
    }

    // MARK: - Persistence

    private func load() {
        guard template == nil, let set = store.set(id: setID),
              let t = set.templates.first(where: { $0.id == templateID }) else { return }
        template = t
        previewSize = t.instagramSize
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        guard let t = template, let set = store.set(id: setID), store.canEdit(set) else { return }
        store.upsertTemplate(t, inSet: setID)
    }
}

// MARK: - Zone inspector

private struct ZoneInspector: View {
    @Binding var zone: TemplateZone
    let set: TemplateSet
    let fontNames: [String]
    let onLayerUp: () -> Void
    let onLayerDown: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: zone.zoneType.systemImage)
                TextField("Zone name", text: $zone.name).font(.headline)
                Spacer()
                Toggle(isOn: $zone.isLocked) { Image(systemName: zone.isLocked ? "lock.fill" : "lock.open") }
                    .toggleStyle(.button)
            }

            Picker("Type", selection: $zone.zoneType) {
                ForEach(TemplateZone.ZoneType.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            switch zone.zoneType {
            case .text: textControls
            case .image:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Image slot").font(.subheadline.bold())
                    Picker("Image slot", selection: $zone.imageSlotType) {
                        ForEach(TemplateZone.ImageSlotType.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(zone.imageSlotType == .auto
                         ? "Filled automatically from the Asset Library (shuffleable when creating a post)."
                         : "The user picks a photo from the camera roll or library each time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .logo:
                Text("Shows the first logo from the Asset Library.").font(.caption).foregroundStyle(.secondary)
            case .shape:
                EmptyView()
            }

            backgroundControls
            positionControls

            HStack {
                Button { onLayerDown() } label: { Label("Backward", systemImage: "square.2.layers.3d.bottom.filled") }
                Spacer()
                Button { onLayerUp() } label: { Label("Forward", systemImage: "square.2.layers.3d.top.filled") }
            }
            .buttonStyle(.bordered)

            HStack {
                Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    .buttonStyle(.bordered)
                Spacer()
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                    .buttonStyle(.bordered)
            }
        }
    }

    // Text slot kind + value
    private var slotKind: Binding<String> {
        Binding(
            get: {
                switch zone.textSlotType {
                case .locked: return "locked"
                case .preFilled: return "preFilled"
                case .open: return "open"
                }
            },
            set: { kind in
                let current = zone.textSlotType.defaultText
                switch kind {
                case "locked": zone.textSlotType = .locked(current.isEmpty ? zone.name : current)
                case "preFilled": zone.textSlotType = .preFilled(current)
                default: zone.textSlotType = .open
                }
            }
        )
    }

    private var slotValue: Binding<String> {
        Binding(
            get: { zone.textSlotType.defaultText },
            set: { value in
                switch zone.textSlotType {
                case .locked: zone.textSlotType = .locked(value)
                case .preFilled: zone.textSlotType = .preFilled(value)
                case .open: break
                }
            }
        )
    }

    @ViewBuilder
    private var textControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text slot").font(.subheadline.bold())
            Picker("Text slot", selection: slotKind) {
                Text("Open").tag("open")
                Text("Pre-filled").tag("preFilled")
                Text("Locked").tag("locked")
            }
            .pickerStyle(.segmented)
            switch zone.textSlotType {
            case .open:
                TextField("Placeholder hint (e.g. Title)", text: $zone.placeholder)
                    .textFieldStyle(.roundedBorder)
                Text("Left blank – filled fresh every time.").font(.caption).foregroundStyle(.secondary)
            case .preFilled:
                TextField("Default text", text: slotValue, axis: .vertical).textFieldStyle(.roundedBorder)
                prefillShortcuts
                Text("Pre-populated, editable when creating a post.").font(.caption).foregroundStyle(.secondary)
            case .locked:
                TextField("Fixed text", text: slotValue, axis: .vertical).textFieldStyle(.roundedBorder)
                Text("Baked into the template, never changes.").font(.caption).foregroundStyle(.secondary)
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Typography").font(.subheadline.bold())
            Picker("Font", selection: $zone.fontName) {
                Text("System").tag("")
                ForEach(fontNames, id: \.self) { Text($0).tag($0) }
            }
            HStack {
                Picker("Weight", selection: $zone.fontWeight) {
                    ForEach(FontConfig.weights, id: \.self) { Text($0.capitalized).tag($0) }
                }
                Spacer()
                Stepper("\(Int(zone.fontSize)) px", value: $zone.fontSize, in: 12...300, step: 2)
                    .fixedSize()
            }
            Picker("Alignment", selection: $zone.textAlignment) {
                Image(systemName: "text.alignleft").tag(TemplateZone.TextAlignment.leading)
                Image(systemName: "text.aligncenter").tag(TemplateZone.TextAlignment.center)
                Image(systemName: "text.alignright").tag(TemplateZone.TextAlignment.trailing)
            }
            .pickerStyle(.segmented)
            HStack {
                ColorPicker("Text color", selection: $zone.textColorHex.asColor, supportsOpacity: true)
            }
            swatches { zone.textColorHex = $0 }
            Button("Use Brand Heading Font") {
                zone.fontName = set.brandKit.headingFont.fontName
                zone.fontWeight = set.brandKit.headingFont.weight
                zone.fontSize = set.brandKit.headingFont.size
            }
            .font(.caption)
            Button("Use Brand Body Font") {
                zone.fontName = set.brandKit.bodyFont.fontName
                zone.fontWeight = set.brandKit.bodyFont.weight
                zone.fontSize = set.brandKit.bodyFont.size
            }
            .font(.caption)
        }
    }

    private var prefillShortcuts: some View {
        HStack {
            let kit = set.brandKit
            ForEach([("Handle", kit.handle), ("Website", kit.website), ("Tagline", kit.tagline)], id: \.0) { item in
                if !item.1.isEmpty {
                    Button(item.0) { zone.textSlotType = .preFilled(item.1) }
                        .font(.caption).buttonStyle(.bordered)
                }
            }
        }
    }

    private var backgroundControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Background color", isOn: Binding(
                get: { zone.backgroundColorHex != nil },
                set: { zone.backgroundColorHex = $0 ? (zone.backgroundColorHex ?? set.brandKit.primaryColorHex) : nil }
            ))
            .font(.subheadline.bold())
            if zone.backgroundColorHex != nil {
                ColorPicker("Fill", selection: Binding(
                    get: { Color(hex: zone.backgroundColorHex ?? "#000000") },
                    set: { zone.backgroundColorHex = $0.hexString }
                ), supportsOpacity: true)
                swatches { zone.backgroundColorHex = $0 }
            }
        }
    }

    private func swatches(_ apply: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(set.brandKit.palette.enumerated()), id: \.offset) { _, hex in
                Button { apply(hex) } label: {
                    Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                        .overlay(Circle().stroke(Color.secondary.opacity(0.4)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var positionControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Position & Size").font(.subheadline.bold())
            rectSlider("X", value: Binding(get: { zone.normalizedRect.minX },
                                           set: { zone.normalizedRect.origin.x = $0; zone.clampRect() }))
            rectSlider("Y", value: Binding(get: { zone.normalizedRect.minY },
                                           set: { zone.normalizedRect.origin.y = $0; zone.clampRect() }))
            rectSlider("W", value: Binding(get: { zone.normalizedRect.width },
                                           set: { zone.normalizedRect.size.width = $0; zone.clampRect() }))
            rectSlider("H", value: Binding(get: { zone.normalizedRect.height },
                                           set: { zone.normalizedRect.size.height = $0; zone.clampRect() }))
        }
    }

    private func rectSlider(_ label: String, value: Binding<CGFloat>) -> some View {
        HStack {
            Text(label).font(.caption.monospaced()).frame(width: 16)
            Slider(value: value, in: 0...1)
            Text("\(Int(value.wrappedValue * 100))%").font(.caption.monospaced()).frame(width: 40, alignment: .trailing)
        }
    }
}
