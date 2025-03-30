import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";

actor EcoTokenPlatform {
    // Tipe data untuk profil pengguna
    type UserProfile = {
        id: Principal;
        name: Text;
        carbonCredits: Nat;
        sustainabilityScore: Nat;
        environmentalActions: [EnvironmentalAction];
    };

    // Tipe aksi lingkungan
    type EnvironmentalAction = {
        description: Text;
        carbonReduction: Nat;
        timestamp: Int;
        verified: Bool;
    };

    // Tipe transaksi kredit karbon
    type CarbonCreditTransaction = {
        from: Principal;
        to: Principal;
        amount: Nat;
        timestamp: Int;
    };

    // Penyimpanan data
    private var userProfiles = HashMap.HashMap<Principal, UserProfile>(10, Principal.equal, Principal.hash);
    private var carbonCreditTransactions = HashMap.HashMap<Nat, CarbonCreditTransaction>(10, Nat.equal, Nat.hash);
    private var transactionCounter : Nat = 0;

    // Mendaftarkan pengguna baru
    public shared(msg) func registerUser(name: Text) : async Result.Result<Principal, Text> {
        if (userProfiles.get(msg.caller) != null) {
            return #err("User already registered");
        };

        let newUser : UserProfile = {
            id = msg.caller;
            name = name;
            carbonCredits = 0;
            sustainabilityScore = 0;
            environmentalActions = [];
        };

        userProfiles.put(msg.caller, newUser);
        #ok(msg.caller)
    };

    // Mencatat aksi lingkungan
    public shared(msg) func logEnvironmentalAction(
        description: Text, 
        carbonReduction: Nat
    ) : async Result.Result<EnvironmentalAction, Text> {
        switch (userProfiles.get(msg.caller)) {
            case null { return #err("User not registered"); };
            case (?user) {
                let newAction : EnvironmentalAction = {
                    description = description;
                    carbonReduction = carbonReduction;
                    timestamp = Time.now();
                    verified = false;
                };

                let updatedUser : UserProfile = {
                    id = user.id;
                    name = user.name;
                    carbonCredits = user.carbonCredits + carbonReduction;
                    sustainabilityScore = user.sustainabilityScore + 1;
                    environmentalActions = 
                        Array.append(user.environmentalActions, [newAction]);
                };

                userProfiles.put(msg.caller, updatedUser);
                #ok(newAction)
            };
        }
    };

    // Verifikasi aksi lingkungan
    public shared(msg) func verifyEnvironmentalAction(
        userId: Principal,
        actionIndex: Nat
    ) : async Result.Result<EnvironmentalAction, Text> {
        switch (userProfiles.get(userId)) {
            case null { return #err("User not found"); };
            case (?user) {
                if (actionIndex >= user.environmentalActions.size()) {
                    return #err("Invalid action index");
                };

                var action = user.environmentalActions[actionIndex];
                
                // Hanya bisa diverifikasi sekali
                if (action.verified) {
                    return #err("Action already verified");
                };

                // Update aksi terverifikasi
                action := {
                    description = action.description;
                    carbonReduction = action.carbonReduction;
                    timestamp = action.timestamp;
                    verified = true;
                };

                let updatedActions = Array.thaw(user.environmentalActions);
                updatedActions[actionIndex] := action;

                let updatedUser : UserProfile = {
                    id = user.id;
                    name = user.name;
                    carbonCredits = user.carbonCredits;
                    sustainabilityScore = user.sustainabilityScore + 2;
                    environmentalActions = Array.freeze(updatedActions);
                };

                userProfiles.put(userId, updatedUser);
                #ok(action)
            };
        }
    };

    // Transfer kredit karbon
    public shared(msg) func transferCarbonCredits(
        to: Principal, 
        amount: Nat
    ) : async Result.Result<CarbonCreditTransaction, Text> {
        switch (userProfiles.get(msg.caller)) {
            case null { return #err("Sender not registered"); };
            case (?sender) {
                // Cek saldo kredit
                if (sender.carbonCredits < amount) {
                    return #err("Insufficient carbon credits");
                };

                // Pastikan penerima terdaftar
                switch (userProfiles.get(to)) {
                    case null { return #err("Recipient not registered"); };
                    case (?recipient) {
                        // Buat transaksi
                        let transaction : CarbonCreditTransaction = {
                            from = msg.caller;
                            to = to;
                            amount = amount;
                            timestamp = Time.now();
                        };

                        // Update profil pengirim
                        let updatedSender : UserProfile = {
                            id = sender.id;
                            name = sender.name;
                            carbonCredits = sender.carbonCredits - amount;
                            sustainabilityScore = sender.sustainabilityScore;
                            environmentalActions = sender.environmentalActions;
                        };

                        // Update profil penerima
                        let updatedRecipient : UserProfile = {
                            id = recipient.id;
                            name = recipient.name;
                            carbonCredits = recipient.carbonCredits + amount;
                            sustainabilityScore = recipient.sustainabilityScore;
                            environmentalActions = recipient.environmentalActions;
                        };

                        userProfiles.put(msg.caller, updatedSender);
                        userProfiles.put(to, updatedRecipient);

                        // Catat transaksi
                        carbonCreditTransactions.put(transactionCounter, transaction);
                        transactionCounter += 1;

                        #ok(transaction)
                    };
                }
            };
        }
    };

    // Dapatkan profil pengguna
    public query func getUserProfile(userId: Principal) : async ?{
        name: Text;
        carbonCredits: Nat;
        sustainabilityScore: Nat;
    } {
        switch (userProfiles.get(userId)) {
            case null { null };
            case (?user) {
                ?{
                    name = user.name;
                    carbonCredits = user.carbonCredits;
                    sustainabilityScore = user.sustainabilityScore;
                }
            };
        }
    };
}
