protocol UsersRepository {

    func registerUser(_ user: User) async -> Bool
    func loadUsers() async -> [User]

}
