module json_serialization;

import std.stdio;
import std.traits;
import std.typecons;
import std.datetime;
import std.json;

// TODO: Handle Array and Dict
T fromJSONValue(T)(JSONValue data)
{
    static if (is(T == struct))
        T result;
    else
        T result = new T;

 	alias fieldTypes = FieldTypeTuple!(T);
	alias fieldNames = FieldNameTuple!(T);

    static foreach(idx, fieldName; fieldNames)
    {
        {
            // Field name same as memberName unless @JSONFieldName
            // attribute added to the member.
            enum name = getJSONFieldName!(T, fieldName);

            // Add to Struct if exists in the input JSONValue
            mixin("if (\"" ~ name ~ "\" in data) result." ~ fieldName ~ " = data[\"" ~ name ~ "\"].get!" ~ fieldTypes[idx].stringof ~ ";");
        }
    }

    return result;
}

/// UDA.
struct JSONFieldName
{
    string name;
}

/// UDA. struct members with @JSONFieldIgnore will be ignored while parsing JSON 
public enum JSONFieldIgnore; 

// TODO: Add new UDA for emitNull

string getJSONFieldName(T, string member)()
{
    static if (getUDAs!(__traits(getMember, T, member), JSONFieldName).length > 0)
        return getUDAs!(__traits(getMember, T, member), JSONFieldName)[0].name;

    return member;
}

bool isJSONFieldIgnored(T, string member)()
{
    return hasUDA!(__traits(getMember, T, member), JSONFieldIgnore);
}

JSONValue toJSONValue(T)(T data)
{
    JSONValue result;

 	alias fieldTypes = FieldTypeTuple!(T);
	alias fieldNames = FieldNameTuple!(T);
	alias fieldValues = data.tupleof;   

    static foreach(idx, fieldName; fieldNames)
    {
        {
            // TODO: Check if the field is struct/class
            static if (!isJSONFieldIgnored!(T, fieldName))
            {
                // Field name same as memberName unless @JSONFieldName
                // attribute added to the member.
                enum name = getJSONFieldName!(T, fieldName);

                result[fieldName] = JSONValue(fieldValues[idx]);
            }
        }
    }

    return result;
}

string toJSONValueString(T)(T data)
{
    return data.toJSONValue.toString;
}

T fromJSONValueString(T)(string data)
{
     return fromJSONValue!T(parseJSON(data));
}

unittest
{
    struct KeyValue1
    {
        string key;
        int value;
    }

    auto data1 = KeyValue1("ABCD", 100);
    JSONValue expect1;
    expect1["key"] = "ABCD";
    expect1["value"] = 100;
    assert(data1.toJSONValue == expect1);

    struct KeyValue2
    {
        @JSONFieldName("name") string key;
        @JSONFieldIgnore string key1;
        int value;
    }

    auto data2 = KeyValue2("ABCD", "EFGH", 200);
    JSONValue expect2;
    expect2["name"] = "ABCD";
    expect2["value"] = 200;
    assert(data1.toJSONValue == expect1);

    // Deserialization
    assert(fromJSONValue!KeyValue1(expect1) == data1);
    
}
