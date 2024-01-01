use super::pow::get_pow;

#[derive(Copy, Drop, Serde, Debug)]
struct Pack {
    first: felt252,
    second: felt252,
    third: felt252
}


#[generate_trait]
impl PackImpl of PackTrait {
    // u256 -> felt252, u256 must <= 0x800000000000011000000000000000000000000000000000000000000000000
    fn new() -> Pack {
        Pack { first: 0, second: 0, third: 0, }
    }

    /// Sets a bit at the specified position in a `Pack` value.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `Pack` struct representing the value to modify.
    /// * `position` - An `u128` representing the position of the bit to set.
    ///
    /// # Panics
    ///
    /// This function will panic if the `position` is greater than or equal to 625.
    fn set_bit(ref self: Pack, position: u128) {
        assert(position < 625, 'invalid position');
        if position < 248 {
            self
                .first = (self.first.into() | get_pow(247 - position))
                .try_into()
                .expect('set bit overflow 248');
        } else if position < 496 {
            self
                .second = (self.second.into() | get_pow(247 - position % 248))
                .try_into()
                .expect('set bit overflow 496');
        } else {
            self
                .third = (self.third.into() | get_pow(247 - position % 248))
                .try_into()
                .expect('set bit overflow 625');
        }
    }

    /// Retrieves the value of a bit at the specified position in a `Pack` value.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `Pack` struct representing the value to retrieve the bit from.
    /// * `position` - An `u128` representing the position of the bit to retrieve.
    ///
    /// # Panics
    ///
    /// This function will panic if the `position` is greater than or equal to 625.
    ///
    /// # Returns
    ///
    /// A boolean value indicating whether the bit at the specified position is set (`true`) or not (`false`).
    fn get_bit(self: Pack, position: u128) -> bool {
        assert(position < 625, 'invalid position');
        if position < 248 {
            self.first.into() | get_pow(247 - position) == self.first.into()
        } else if position < 496 {
            self.second.into() | get_pow(247 - position % 248) == self.second.into()
        } else {
            self.third.into() | get_pow(247 - position % 248) == self.third.into()
        }
    }

    /// Adds the corresponding bits of two `Pack` values and stores the result in the current `Pack` instance.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `Pack` struct representing the current value.
    /// * `other` - A `Pack` struct representing the value to be added.
    ///
    /// # Panics
    ///
    /// This function will panic if the addition of any bit overflows the maximum value of `u256`.
    fn add_bit(ref self: Pack, other: Pack) {
        let mut result: u256 = self.first.into() | other.first.into();
        self.first = result.try_into().expect('add bit overflow');

        result = self.second.into() | other.second.into();
        self.second = result.try_into().expect('add bit overflow');

        result = self.third.into() | other.third.into();
        self.third = result.try_into().expect('add bit overflow');
    }

    /// Subtracts the corresponding bits of two `Pack` values and stores the result in the current `Pack` instance.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `Pack` struct representing the current value.
    /// * `other` - A `Pack` struct representing the value to be subtracted.
    ///
    /// # Panics
    ///
    /// This function will panic if the subtraction of any bit overflows the maximum value of `u256`.
    fn subtract_bit(ref self: Pack, other: Pack) {
        let mut result: u256 = self.first.into() & ~other.first.into();
        self.first = result.try_into().expect('sub bit overflow');

        result = self.second.into() & ~other.second.into();
        self.second = result.try_into().expect('sub bit overflow');

        result = self.third.into() & ~other.third.into();
        self.third = result.try_into().expect('sub bit overflow');
    }

    /// Counts the number of set bits in the `Pack` value.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `Pack` struct representing the value to count the bits in.
    ///
    /// # Returns
    ///
    /// The total count of set bits as a `u128`.
    fn count_bit(self: Pack) -> u128 {
        let mut count: u128 = 0;
        count_loop(self.first.into(), count)
            + count_loop(self.second.into(), count)
            + count_loop(self.third.into(), count)
    }
}


fn count_loop(mut value: u256, mut count: u128) -> u128 {
    if value != 0 {
        value = value & (value - 1);
        count += 1;
        count_loop(value, count)
    } else {
        count
    }
}

#[cfg(test)]
mod test {
    use super::{Pack, PackTrait};

    fn p<T, impl TPrint: PrintTrait<T>>(t: T) {
        t.print();
    }

    use debug::PrintTrait;

    #[test]
    #[ignore]
    #[available_gas(3000000)]
    fn test() {
        let mut pack: Pack = Pack { first: 0, second: 0, third: 0 };
        pack.set_bit(66);
        assert(pack.get_bit(66), 'set bit');
    }
}
