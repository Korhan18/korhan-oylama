import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Hash "mo:base/Hash";

actor VotingSystem {
    // Types
    type Election = {
        name: Text;
        description: Text;
        options: [Text];
        isActive: Bool;
    };

    // Store elections and votes using stable var
    private stable var electionEntries : [(Text, Election)] = [];
    private stable var votesEntries : [(Text, [(Nat32, Nat32)])] = [];
    
    // Initialize HashMaps
    private var elections = HashMap.fromIter<Text, Election>(electionEntries.vals(), 10, Text.equal, Text.hash);
    private var votes = HashMap.fromIter<Text, [(Nat32, Nat32)]>(votesEntries.vals(), 10, Text.equal, Text.hash);

    // System upgrade hooks
    system func preupgrade() {
        electionEntries := Iter.toArray(elections.entries());
        votesEntries := Iter.toArray(votes.entries());
    };

    system func postupgrade() {
        electionEntries := [];
        votesEntries := [];
    };

    // Create a new election
    public func createElection(electionId: Text, name: Text, description: Text, options: [Text]) : async Bool {
        switch (elections.get(electionId)) {
            case (?_) { false }; // Election already exists
            case null {
                let newElection : Election = {
                    name = name;
                    description = description;
                    options = options;
                    isActive = true;
                };
                elections.put(electionId, newElection);
                votes.put(electionId, []);
                true
            };
        }
    };

    // Vote in an election
    public func vote(electionId: Text, voterId: Nat32, optionId: Nat32) : async Bool {
        switch (elections.get(electionId)) {
            case (?election) {
                if (not election.isActive) {
                    return false;
                };

                // Get current votes for this election
                switch (votes.get(electionId)) {
                    case (?currentVotes) {
                        // Check if voter has already voted
                        for ((voter, _) in currentVotes.vals()) {
                            if (voter == voterId) {
                                return false;
                            };
                        };

                        // Check if option is valid
                        if (optionId < 1 or optionId > Nat32.fromNat(election.options.size())) {
                            return false;
                        };

                        // Add new vote
                        let newVotes = Array.append(currentVotes, [(voterId, optionId)]);
                        votes.put(electionId, newVotes);
                        true
                    };
                    case null {
                        votes.put(electionId, [(voterId, optionId)]);
                        true
                    };
                }
            };
            case null { false };
        }
    };

    // Get election details and results
    public query func getElection(electionId: Text) : async ?{
        name: Text;
        description: Text;
        options: [Text];
        results: [(Nat32, Nat32)]; // (optionId, voteCount)
        isActive: Bool;
    } {
        switch (elections.get(electionId)) {
            case (?election) {
                switch (votes.get(electionId)) {
                    case (?electionVotes) {
                        // Count votes for each option
                        var results : [(Nat32, Nat32)] = [];
                        for (i in Iter.range(1, election.options.size())) {
                            var count : Nat32 = 0;
                            let optionId = Nat32.fromNat(i);
                            for ((_, vote) in electionVotes.vals()) {
                                if (vote == optionId) {
                                    count += 1;
                                };
                            };
                            results := Array.append(results, [(optionId, count)]);
                        };

                        ?{
                            name = election.name;
                            description = election.description;
                            options = election.options;
                            results = results;
                            isActive = election.isActive;
                        }
                    };
                    case null {
                        ?{
                            name = election.name;
                            description = election.description;
                            options = election.options;
                            results = [];
                            isActive = election.isActive;
                        }
                    };
                }
            };
            case null { null };
        }
    };
}
