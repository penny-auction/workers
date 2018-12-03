# frozen_string_literal: true

class SmartContractService

  DEFAULT_GAS_PRICE = 1_000_000_000
  DEFAULT_GAS_LIMIT = 250_000

  Error = Class.new(StandardError)
  attr_reader :configuration

  def initialize(gas_price: nil, gas_limit: nil)
    @configuration = Rails.configuration.x.geth_configuration
    @json_rpc_endpoint = configuration[:rpc_endpoint]
    @json_rpc_call_id = 0
    @gas_price = gas_price || DEFAULT_GAS_PRICE
    @gas_limit = gas_limit || DEFAULT_GAS_LIMIT
  end

  #function addNewLot(
  # uint256 _initialPrice,
  # uint256 _bidIncrement,
  #)
  #
  def add_new_lot(initial_price:, bid_increment:)
    binding.pry
    data = abi_encode(
      'addNewLot(uint256,uint256)',
      '0x' + initial_price.to_i.to_s(16),
      '0x' + bid_increment.to_i.to_s(16),
    )

    eth_send_transaction(data)
  end

  def create_bid(lot_id, depositor_uid)
    # binding.pry
    data = abi_encode(
      'bid(uint256,string)',
      '0x' + lot_id.to_i.to_s(16),
      '0x' + depositor_uid
    )

    eth_send_transaction(data)
  end

  def permit_transaction(issuer)
    json_rpc(:personal_unlockAccount, [normalize_address(issuer.fetch(:address)), issuer.fetch(:secret), 5]).tap do |response|
      unless response['result']
        raise Error, \
            "Transaction from #{normalize_address(issuer[:address])} is not permitted."
      end
    end
  end

  private

  def abi_encode(method, *args)
    '0x' + args.each_with_object(Digest::SHA3.hexdigest(method, 256)[0...8]) do |arg, data|
      data.concat(arg.gsub(/\A0x/, '').rjust(64, '0'))
    end
  end

  def eth_send_transaction(data)
    issuer = configuration.fetch(:issuer)
    contract_address = configuration.fetch(:contract_address)
    permit_transaction(issuer)

    json_rpc(
      :eth_sendTransaction,
      [{
         from: normalize_address(issuer.fetch(:address)),
         to:   contract_address,
         data: data,
         gas: '0x' + @gas_limit.to_s(16),
         gasPrice: '0x' + @gas_price.to_s(16)
       }]
    ).fetch('result').yield_self do |txid|
      raise Error, \
          "Transaction from #{normalize_address(issuer[:address])} failed." \
            unless valid_txid?(normalize_txid(txid))
      normalize_txid(txid)
    end
  end


  def connection
    Faraday.new(@json_rpc_endpoint)
  end

  def json_rpc(method, params = [])
    response = connection.post \
      '/',
      { jsonrpc: '2.0', id: @json_rpc_call_id += 1, method: method, params: params }.to_json,
      { 'Accept'       => 'application/json',
        'Content-Type' => 'application/json' }
    response.assert_success!
    response = JSON.parse(response.body)
    response['error'].tap { |error| raise Error, error.inspect if error }
    response
  end

  def normalize_address(address)
    address.downcase
  end

  def normalize_txid(txid)
    txid.downcase
  end

  def valid_txid?(txid)
    txid.to_s.match?(/\A0x[A-F0-9]{64}\z/i)
  end
end
