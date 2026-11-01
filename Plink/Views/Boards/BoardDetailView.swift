import SwiftUI

struct BoardDetailView: View {
    let board: Board
    @State private var showingRename = false

    var body: some View {
        PinGridView(board: board)
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingRename = true
                    } label: {
                        Label("Edit Board", systemImage: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showingRename) {
                BoardEditorView(board: board)
            }
    }
}
