# frozen_string_literal: false
require 'test/unit'
require "xmlrpc/marshal"

module TestXMLRPC
class Test_Marshal < Test::Unit::TestCase
  # for test_parser_values
  class Person
    include XMLRPC::Marshallable
    attr_reader :name
    def initialize(name)
      @name = name
    end
  end

  # for test_load_call_class_not_marshallable
  class Person2
    attr_reader :name
    def initialize(name)
      @name = name
    end
  end

  def test1_dump_response
    assert_nothing_raised(NameError) {
      XMLRPC::Marshal.dump_response('arg')
    }
  end

  def test1_dump_call
    assert_nothing_raised(NameError) {
      XMLRPC::Marshal.dump_call('methodName', 'arg')
    }
  end

  def test2_dump_load_response
    value = [1, 2, 3, {"test" => true}, 3.4]
    res   = XMLRPC::Marshal.dump_response(value)

    assert_equal(value, XMLRPC::Marshal.load_response(res))
  end

  def test2_dump_load_call
    methodName = "testMethod"
    value      = [1, 2, 3, {"test" => true}, 3.4]
    exp        = [methodName, [value, value]]

    res   = XMLRPC::Marshal.dump_call(methodName, value, value)

    assert_equal(exp, XMLRPC::Marshal.load_call(res))
  end

  def test_parser_values
    v1 = [
      1, -7778, -(2**31), 2**31-1,     # integers
      1.0, 0.0, -333.0, 2343434343.0,  # floats
      false, true, true, false,        # booleans
      "Hallo", "with < and >", ""      # strings
    ]

    v2 = [
      [v1, v1, v1],
      {"a" => v1}
    ]

    v3 = [
      XMLRPC::Base64.new("\001"*1000), # base64
      :aSymbol, :anotherSym            # symbols (-> string)
    ]
    v3_exp = [
      "\001"*1000,
      "aSymbol", "anotherSym"
    ]
    person = Person.new("Michael")

    XMLRPC::XMLParser.each_installed_parser do |parser|
      m = XMLRPC::Marshal.new(parser)

      assert_equal( v1, m.load_response(m.dump_response(v1)) )
      assert_equal( v2, m.load_response(m.dump_response(v2)) )
      assert_equal( v3_exp, m.load_response(m.dump_response(v3)) )

      pers = m.load_response(m.dump_response(person))

      assert_kind_of( Person, pers )
      assert_equal( person.name, pers.name )
    end

    # missing, Date, Time, DateTime
    # Struct
  end

  def test_parser_invalid_values
    values = [
      -1-(2**31), 2**31,
      Float::INFINITY, -Float::INFINITY, Float::NAN
    ]
    XMLRPC::XMLParser.each_installed_parser do |parser|
      m = XMLRPC::Marshal.new(parser)

      values.each do |v|
        assert_raise(RuntimeError, "#{v} shouldn't be dumped, but dumped") \
          { m.dump_response(v) }
      end
    end
  end

  def test_no_params_tag
    # bug found by Idan Sofer

    expect = %{<?xml version="1.0" ?><methodCall><methodName>myMethod</methodName><params/></methodCall>\n}

    str = XMLRPC::Marshal.dump_call("myMethod")
    assert_equal(expect, str)
  end

  # tests for vulnerability of unsafe deserialization when ENABLE_MARSHALLING is set to true
  def test_load_call_class_marshallable
    # return of load call should contain an instance of Person 
    input_xml = %{<?xml version="1.0" ?><methodCall><methodName>myMethod</methodName><params><param><value><struct><member><name>___class___</name><value><string>TestXMLRPC::Test_Marshal::Person</string></value></member><member><name>name</name><value><string>John Doe</string></value></member></struct></value></param></params></methodCall>\n}
    m =  XMLRPC::Marshal.load_call(input_xml)
    assert_kind_of( Person, m[1][0] )
    assert_instance_of( Person, m[1][0] ) 
  end

  def test_load_call_class_not_marshallable
    # return of load call should contain hash instance since Person2 does not include XMLRPC::Marshallable
    hash_exp = Hash.new
    input_xml = %{<?xml version="1.0" ?><methodCall><methodName>myMethod</methodName><params><param><value><struct><member><name>___class___</name><value><string>TestXMLRPC::Test_Marshal::Person2</string></value></member><member><name>name</name><value><string>John Doe</string></value></member></struct></value></param></params></methodCall>\n}
    m=  XMLRPC::Marshal.load_call(input_xml)
    assert_kind_of( Hash, m[1][0] )
    assert_instance_of( Hash, m[1][0] ) 
  end
  
end
end
