#[starknet::contract]
mod Counter {
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use core::starknet::event::EventEmitter;
    use starknet::ContractAddress;
    use kill_switch::IKillSwitchDispatcher;
    use kill_switch::IKillSwitchDispatcherTrait;

    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        counter: u32
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_value: u32,
        kill_switch: ContractAddress,
        initial_owner: ContractAddress
    ) {
        self.ownable.initializer(initial_owner);
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
    }

    #[abi(embed_v0)]
    impl Counter of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let kill_switch_dispatcher: IKillSwitchDispatcher = IKillSwitchDispatcher {
                contract_address: self.kill_switch.read()
            };

            let is_active = kill_switch_dispatcher.is_active();

            assert!(!is_active, "Kill Switch is active");

            if !is_active {
                self.counter.write(self.counter.read() + 1);
                self.emit(CounterIncreased { counter: self.counter.read() })
            }
        }
    }
}

#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}
