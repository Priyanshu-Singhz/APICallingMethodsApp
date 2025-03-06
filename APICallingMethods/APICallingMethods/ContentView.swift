//
//  ContentView.swift
//  APICallingMethods
//
//  Created by Priyanshu Singh on 06/03/25.
//

import SwiftUI
import Combine
import Alamofire

// MARK: - Data Model
struct PostModel: Identifiable, Codable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

// MARK: - ViewModel
@MainActor
class PostsViewModel: ObservableObject {
    @Published var posts: [PostModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiURL = "https://jsonplaceholder.typicode.com/posts"
    
    // Method 1: Using async/await
    func fetchPostsAsync() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: apiURL) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            posts = try JSONDecoder().decode([PostModel].self, from: data)
            isLoading = false
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // Method 2: Using completion handlers
    func fetchPostsWithCompletionHandler(completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: apiURL) else {
            errorMessage = "Invalid URL"
            isLoading = false
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                    completion(false)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                    self.isLoading = false
                    completion(false)
                }
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([PostModel].self, from: data)
                DispatchQueue.main.async {
                    self.posts = decodedData
                    self.isLoading = false
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Decoding error: \(error.localizedDescription)"
                    self.isLoading = false
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Method 3: Using Combine
    func fetchPostsWithCombine() {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: apiURL) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [PostModel].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] value in
                self?.posts = value
            })
            .store(in: &cancellables)
    }
    
    // Method 4: Using Alamofire
    func fetchPostsWithAlamofire() {
        isLoading = true
        errorMessage = nil
        
        AF.request(apiURL)
            .validate()
            .responseDecodable(of: [PostModel].self) { [weak self] response in
                guard let self = self else { return }
                self.isLoading = false
                
                switch response.result {
                case .success(let posts):
                    self.posts = posts
                case .failure(let error):
                    self.errorMessage = "Alamofire Error: \(error.localizedDescription)"
                }
            }
    }
    
    // Clear state for new request
    func reset() {
        posts = []
        errorMessage = nil
    }
}

// MARK: - Main View
struct APIDemoView: View {
    @StateObject private var viewModel = PostsViewModel()
    @State private var selectedMethod = 0
    
    let methods = ["Async/Await", "Completion Handler", "Combine", "Alamofire"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Method Selection
                Picker("API Method", selection: $selectedMethod) {
                    ForEach(0..<methods.count, id: \.self) { index in
                        Text(methods[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedMethod) { _ in
                    viewModel.reset()
                }
                
                // Method Description
                VStack(alignment: .leading) {
                    Text("Method: \(methods[selectedMethod])")
                        .font(.headline)
                    
                    Text(descriptionForMethod(selectedMethod))
                        .font(.subheadline)
                        .padding(.vertical, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Fetch Button
                Button(action: {
                    fetchData()
                }) {
                    Text("Fetch Posts")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(viewModel.isLoading)
                
                // Loading Indicator
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
                
                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Results
                List {
                    ForEach(viewModel.posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.title)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text(post.body)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("API Calling Methods")
        }
    }
    
    private func fetchData() {
        switch selectedMethod {
        case 0:
            Task {
                await viewModel.fetchPostsAsync()
            }
        case 1:
            viewModel.fetchPostsWithCompletionHandler { _ in }
        case 2:
            viewModel.fetchPostsWithCombine()
        case 3:
            viewModel.fetchPostsWithAlamofire()
        default:
            break
        }
    }
    
    private func descriptionForMethod(_ index: Int) -> String {
        switch index {
        case 0:
            return "Modern Swift concurrency pattern using async/await. Clean and readable code that doesn't block the main thread."
        case 1:
            return "Traditional callback-based approach using completion handlers. More verbose but widely supported."
        case 2:
            return "Reactive programming approach using Apple's Combine framework. Great for chaining operations and handling data streams."
        case 3:
            return "Using the popular third-party networking library Alamofire. Provides powerful features beyond URLSession."
        default:
            return ""
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    var body: some View {
        APIDemoView()
    }
}

#Preview {
    ContentView()
}
