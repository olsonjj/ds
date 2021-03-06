/*
Copyright (c) 2008-2016 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.ds;

import de.polygonal.ds.tools.Assert.assert;
import de.polygonal.ds.NativeArray;
import de.polygonal.ds.tools.GrowthRate;
import de.polygonal.ds.tools.M;

using de.polygonal.ds.tools.NativeArrayTools;

/**
	A growable, dense array.
	
	Example:
		var o = new de.polygonal.ds.ArrayList<Int>();
		for (i in 0...4) o.pushBack(i);
		trace(o); //outputs:
		
		[ ArrayList size=4 capacity=4
		  0 -> 0
		  1 -> 1
		  2 -> 2
		  3 -> 3
		]
**/
#if generic
@:generic
#end
class ArrayList<T> implements List<T>
{
	/**
		A unique identifier for this object.
		
		A hash table transforms this key into an index of an array element by using a hash function.
	**/
	public var key(default, null):Int = HashKey.next();
	
	/**
		The size of the allocated storage space for the elements.
		If more space is required to accommodate new elements, `capacity` grows according to `this.growthRate`.
		The capacity never falls below the initial size defined in the constructor and is usually a bit larger than `this.size` (_mild overallocation_).
	**/
	public var capacity(default, null):Int;
	
	/**
		The growth rate of the container.
		@see `GrowthRate`
	**/
	public var growthRate:Int = GrowthRate.NORMAL;
	
	/**
		If true, reuses the iterator object instead of allocating a new one when calling `this.iterator()`.
		
		The default is false.
		
		_If this value is true, nested iterations will fail as only one iteration is allowed at a time._
	**/
	public var reuseIterator:Bool = false;
	
	var mData:NativeArray<T>;
	var mInitialCapacity:Int;
	var mSize:Int = 0;
	var mIterator:ArrayListIterator<T> = null;
	
	/**
		@param initialCapacity the initial physical space for storing values.
		Useful before inserting a large number of elements as this reduces the amount of incremental reallocation.
		@param source Copies all values from `source` in the range [0, `source.length` - 1] to this collection.
	**/
	public function new(initalCapacity:Null<Int> = 2, ?source:Array<T>)
	{
		mInitialCapacity = M.max(2, initalCapacity);
		
		if (source != null && source.length > 0)
		{
			mSize = source.length;
			mData = source.ofArray();
			capacity = size;
		}
		else
		{
			capacity = mInitialCapacity;
			mData = NativeArrayTools.alloc(capacity);
		}
	}
	
	/**
		Returns the element stored at index `i`.
	**/
	public inline function get(i:Int):T
	{
		assert(i >= 0 && i < size, 'index $i out of range ${size - 1}');
		
		return mData.get(i);
	}
	
	/**
		Replaces the element at index `i` with `val`.
	**/
	public inline function set(i:Int, val:T)
	{
		assert(i >= 0 && i < size, 'index $i out of range $size');
		
		mData.set(i, val);
	}
	
	/**
		Appends `val`, same as `this.pushBack()`.
	**/
	public inline function add(val:T)
	{
		pushBack(val);
	}
	
	/**
		Adds `val` to the end of this list and returns the new size.
	**/
	public inline function pushBack(val:T):Int
	{
		if (size == capacity) grow();
		mData.set(mSize++, val);
		return size;
	}
	
	/**
		Faster than `this.pushBack()` by skipping boundary checking.
		
		The user is responsible for making sure that there is enough space available (e.g. by calling `this.reserve()`).
	**/
	public inline function unsafePushBack(val:T):Int
	{
		assert(mSize < capacity, "out of space");
		
		mData.set(mSize++, val);
		return size;
	}
	
	/**
		Removes the last element from this list and returns that element.
	**/
	public inline function popBack():T
	{
		assert(size > 0);
		
		return mData.get(--mSize);
	}
	
	/**
		Removes and returns the first element.
		
		To fill the gap, any subsequent elements are shifted to the left (indices - 1).
	**/
	public function popFront():T
	{
		assert(size > 0, "list is empty");
		
		var d = mData;
		var x = d.get(0);
		if (--mSize == 0) return x;
		
		#if (neko || java || cs || cpp)
		d.blit(1, d, 0, size);
		#else
		for (i in 0...size) d.set(i, d.get(i + 1));
		#end
		return x;
	}
	
	/**
		Prepends `val` to the first element and returns the new size.
		
		Shifts the first element (if any) and any subsequent elements to the right (indices + 1).
	**/
	public function pushFront(val:T):Int
	{
		if (size == 0)
		{
			mData.set(0, val);
			return ++mSize;
		}
		
		if (size == capacity) grow();
		
		#if (neko || java || cs || cpp)
		mData.blit(0, mData, 1, size);
		mData.set(0, val);
		#else
		var d = mData;
		var i = size;
		while (i > 0)
		{
			d.set(i, d.get(i - 1));
			i--;
		}
		d.set(0, val);
		#end
		return ++mSize;
	}
	
	/**
		Returns the first element.
		This is the element at index 0.
	**/
	public inline function front():T
	{
		assert(size > 0, "list is empty");
		
		return mData.get(0);
	}
	
	/**
		Returns the last element.
		This is the element at index `this.size` - 1.
	**/
	public inline function back():T
	{
		assert(size > 0, "list is empty");
		
		return mData.get(size - 1);
	}
	
	/**
		Swaps the element stored at index `i` with the element stored at index `j`.
	**/
	public inline function swap(i:Int, j:Int):ArrayList<T>
	{
		assert(i != j, 'index i equals index j ($i)');
		assert(i >= 0 && i <= size, 'index i=$i out of range $size');
		assert(j >= 0 && j <= size, 'index j=$j out of range $size');
		
		var d = mData;
		var t = d.get(i);
		d.set(i, d.get(j));
		d.set(j, t);
		return this;
	}
	
	/**
		Replaces the element at index `dst` with the element stored at index `src`.
	**/
	public inline function copy(src:Int, dst:Int):ArrayList<T>
	{
		assert(src != dst, 'src index equals dst index ($src)');
		assert(src >= 0 && src <= size, 'index src=$src out of range $size');
		assert(dst >= 0 && dst <= size, 'index dst=$dst out of range $size');
		
		var d = mData;
		d.set(dst, d.get(src));
		return this;
	}
	
	/**
		Returns true if the index `i` is valid for reading a value.
	**/
	public inline function inRange(i:Int):Bool
	{
		return i >= 0 && i < size;
	}
	
	/**
		Inserts `val` at the specified `index`.
		
		Shifts the element currently at that position (if any) and any subsequent elements to the right (indices + 1).
		If `index` equals `this.size`, `val` gets appended to the end of the list.
	**/
	public function insert(index:Int, val:T)
	{
		assert(index >= 0 && index <= size, 'index $index out of range $size');
		
		if (size == capacity) grow();
		#if (neko || java || cs || cpp)
		var srcPos = index;
		var dstPos = index + 1;
		mData.blit(srcPos, mData, dstPos, size - index);
		mData.set(index, val);
		#else
		var d = mData;
		var p = size;
		while (p > index) d.set(p--, d.get(p));
		d.set(index, val);
		#end
		mSize++;
	}
	
	/**
		Removes the element at the specified index `i`.
		
		Shifts any subsequent elements to the left (indices - 1).
	**/
	public function removeAt(i:Int):T
	{
		assert(i >= 0 && i < size, 'index $i out of range ${size - 1}');
		
		var d = mData;
		var x = d.get(i);
		#if (neko || java || cs || cpp)
		d.blit(i + 1, d, i, --mSize - i);
		#else
		var k = --mSize;
		var p = i;
		while (p < k) d.set(p++, d.get(p));
		#end
		return x;
	}
	
	/**
		Fast removal of the element at index `i` if the order of the elements doesn't matter.
		
		@return the element at index `i` prior removal.
	**/
	public inline function swapPop(i:Int):T
	{
		assert(i >= 0 && i < size, 'index $i out of range ${size}');
		
		var d = mData;
		var x = d.get(i);
		d.set(i, d.get(--mSize));
		return x;
	}
	
	/**
		Calls `f` on all elements.
		
		The function signature is: `f(input, index):output`
		
		- input: current element
		- index: the index number of the given element
		- output: element to be stored at given index
	**/
	public function forEach(f:T->Int->T):ArrayList<T>
	{
		assert(f != null);
		
		var d = mData;
		for (i in 0...size) d.set(i, f(d.get(0), i));
		return this;
	}
	
	/**
		Cuts of `this.size` - `n` elements.
		
		This only modifies the value of `this.size` and does not perform reallocation.
	**/
	public function trim(n:Int):ArrayList<T>
	{
		assert(n <= size, 'new size ($n) > current size ($size)');
		
		mSize = n;
		return this;
	}
	
	/**
		Converts the data in this dense array to strings, inserts `sep` between the elements, concatenates them, and returns the resulting string.
	**/
	public function join(sep:String):String
	{
		if (size == 0) return "";
		
		#if (flash || cpp)
		var t = NativeArrayTools.alloc(size);
		mData.blit(0, t, 0, size);
		return t.join(sep);
		#else
		var k = size;
		if (k == 0) return "";
		if (k == 1) return Std.string(front());
		var b = new StringBuf(), d = mData;
		b.add(Std.string(front()) + sep);
		for (i in 1...k - 1)
		{
			b.add(Std.string(d.get(i)));
			b.add(sep);
		}
		b.add(Std.string(d.get(k - 1)));
		return b.toString();
		#end
	}
	
	/**
		Finds the first occurrence of `val` by using the binary search algorithm assuming elements are sorted.
		@param from the index to start from. The default value is 0.
		@param cmp a comparison function for the binary search. If omitted, the method assumes that all elements implement `Comparable`.
		@return the index storing `val` or the bitwise complement (~) of the index where the `val` would be inserted (guaranteed to be a negative number).<br/>
		_The insertion point is only valid if `from` is 0._
	**/
	public function binarySearch(val:T, from:Int, ?cmp:T->T->Int):Int
	{
		assert(from >= 0 && from <= size, 'from index out of range ($from)');
		
		if (size == 0) return -1;
		
		if (cmp != null) return mData.binarySearchCmp(val, from, size - 1, cmp);
		
		assert(Std.is(val, Comparable), "element is not of type Comparable");
		
		var k = size;
		var l = from, m, h = k, d = mData;
		while (l < h)
		{
			m = l + ((h - l) >> 1);
			
			assert(Std.is(d.get(m), Comparable), "element is not of type Comparable");
			
			if (cast(d.get(m), Comparable<Dynamic>).compare(val) < 0)
				l = m + 1;
			else
				h = m;
		}
		
		assert(Std.is(d.get(l), Comparable), "element is not of type Comparable");
		
		return ((l <= k) && (cast(d.get(l), Comparable<Dynamic>).compare(val)) == 0) ? l : -l;
	}
	
	/**
		Finds the first occurrence of `val` (by incrementing indices - from left to right).
		@return the index storing `val` or -1 if `val` was not found.
	**/
	@:access(de.polygonal.ds.ArrayList)
	public function indexOf(val:T):Int
	{
		if (size == 0) return -1;
		var i = 0, j = -1, k = size - 1, d = mData;
		do
		{
			if (d.get(i) == val)
			{
				j = i;
				break;
			}
		}
		while (i++ < k);
		return j;
	}
	
	/**
		Finds the first occurrence of `val` (by decrementing indices - from right to left) and returns the index storing `val` or -1 if `val` was not found.
		@param from the index to start from.
		<br/>By default, the method starts from the last element in this dense array.
	**/
	public function lastIndexOf(val:T, from:Int = -1):Int
	{
		if (size == 0) return -1;
		
		if (from < 0) from = size + from;
		
		assert(from >= 0 && from < size, 'from index out of range ($from)');
		
		var j = -1;
		var i = from;
		var d = mData;
		do
		{
			if (d.get(i) == val)
			{
				j = i;
				break;
			}
		}
		while (i-- > 0);
		return j;
	}
	
	/**
		Concatenates this array with `val` by appending all elements of `val` to this array.
		@param copy if true, returns a new array instead of modifying this array.
	**/
	public function concat(val:ArrayList<T>, copy:Bool = false):ArrayList<T>
	{
		assert(val != null);
		
		if (copy)
		{
			var sum = size + val.size;
			var out = new ArrayList<T>(sum);
			out.mSize = sum;
			mData.blit(0, out.mData, 0, size);
			val.mData.blit(0, out.mData, size, val.size);
			return out;
		}
		else
		{
			assert(val != this, "val equals this");
			
			var sum = size + val.size;
			reserve(sum);
			val.mData.blit(0, mData, size, val.size);
			mSize = sum;
			return this;
		}
	}
	
	/**
		Reverses this list in place in the range [`first`, `last`] (the first element becomes the last and the last becomes the first).
	**/
	public function reverse(first:Int = -1, last:Int = -1)
	{
		if (first == -1 || last == -1)
		{
			first = 0;
			last = size;
		}
		
		assert(last - first > 0);
		
		var k = last - first;
		if (k <= 1) return;
		
		var t, u, v, d = mData;
		for (i in 0...k >> 1)
		{
			u = first + i;
			v = last - i - 1;
			t = d.get(u);
			d.set(u, d.get(v));
			d.set(v, t);
		}
	}
	
	/**
		Copies `n` elements from the location pointed by the index `source` to the location pointed by `destination`.
		
		Copying takes place as if an intermediate buffer was used, allowing the destination and source to overlap.
		
		@see http://www.cplusplus.com/reference/clibrary/cstring/memmove/
	**/
	public function blit(destination:Int, source:Int, n:Int)
	{
		assert(destination >= 0 && source >= 0 && n >= 0);
		assert(source < size);
		assert(destination + n <= size);
		assert(n <= size);
		
		mData.blit(source, mData, destination, n);
	}
	
	/**
		Sorts the elements of this dense array using the quick sort algorithm.
		@param cmp a comparison function.
		<br/>If null, the elements are compared using `element.compare()`.
		<br/>_In this case all elements have to implement `Comparable`._
		@param useInsertionSort if true, the dense array is sorted using the insertion sort algorithm.
		<br/>This is faster for nearly sorted lists.
		@param first sort start index. The default value is 0.
		@param count the number of elements to sort (range: [`first`, `first` + `count`]).
		<br/>If omitted, `count` is set to the remaining elements (`this.size` - `first`).
	**/
	public function sort(?cmp:T->T->Int, useInsertionSort:Bool = false, first:Int = 0, count:Int = -1)
	{
		if (size > 1)
		{
			if (count == -1) count = size - first;
			
			assert(first >= 0 && first <= size - 1 && first + count <= size, "first index out of range");
			assert(count >= 0 && count <= size, "count out of range");
			
			if (cmp == null)
				useInsertionSort ? insertionSortComparable(first, count) : quickSortComparable(first, count);
			else
			{
				if (useInsertionSort)
					insertionSort(first, count, cmp);
				else
					quickSort(first, count, cmp);
			}
		}
	}
	
	/**
		Shuffles the elements of this collection by using the Fisher-Yates algorithm.
		@param rvals a list of random double values in the interval [0, 1) defining the new positions of the elements.
		If omitted, random values are generated on-the-fly by calling `Math.random()`.
	**/
	public function shuffle(?rvals:Array<Float>)
	{
		var s = size, d = mData;
		
		if (rvals == null)
		{
			var m = Math;
			while (--s > 1)
			{
				var i = Std.int(m.random() * s);
				var t = d.get(s);
				d.set(s, d.get(i));
				d.set(i, t);
			}
		}
		else
		{
			assert(rvals.length >= size, "insufficient random values");
			
			var j = 0;
			while (--s > 1)
			{
				var i = Std.int(rvals[j++] * s);
				var t = d.get(s);
				d.set(s, d.get(i));
				d.set(i, t);
			}
		}
	}
	
	/**
		Prints out all elements.
	**/
	public function toString():String
	{
		#if no_tostring
		return Std.string(this);
		#else
		var b = new StringBuf();
		b.add('[ ArrayList size=$size capacity=$capacity');
		if (isEmpty())
		{
			b.add(" ]");
			return b.toString();
		}
		b.add("\n");
		var d = mData, args = new Array<Dynamic>();
		var fmt = '  %${M.numDigits(size)}d -> %s\n';
		for (i in 0...size)
		{
			args[0] = i;
			args[1] = Std.string(d.get(i));
			b.add(Printf.format(fmt, args));
		}
		b.add("]");
		return b.toString();
		#end
	}
	
	function quickSort(first:Int, k:Int, cmp:T->T->Int)
	{
		var last = first + k - 1, lo = first, hi = last, d = mData;
		
		var i0, i1, i2, mid, t;
		var t0, t1, t2, pivot;
		
		if (k > 1)
		{
			i0 = first;
			i1 = i0 + (k >> 1);
			i2 = i0 + k - 1;
			t0 = d.get(i0);
			t1 = d.get(i1);
			t2 = d.get(i2);
			t = cmp(t0, t2);
			if (t < 0 && cmp(t0, t1) < 0)
				mid = cmp(t1, t2) < 0 ? i1 : i2;
			else
			{
				if (cmp(t1, t0) < 0 && cmp(t1, t2) < 0)
					mid = t < 0 ? i0 : i2;
				else
					mid = cmp(t2, t0) < 0 ? i1 : i0;
			}
			
			pivot = d.get(mid);
			d.set(mid, d.get(first));
			
			while (lo < hi)
			{
				while (cmp(pivot, d.get(hi)) < 0 && lo < hi) hi--;
				if (hi != lo)
				{
					d.set(lo, d.get(hi));
					lo++;
				}
				while (cmp(pivot, d.get(lo)) > 0 && lo < hi) lo++;
				if (hi != lo)
				{
					d.set(hi, d.get(lo));
					hi--;
				}
			}
			
			d.set(lo, pivot);
			quickSort(first, lo - first, cmp);
			quickSort(lo + 1, last - lo, cmp);
		}
	}
	
	function quickSortComparable(first:Int, k:Int)
	{
		var d = mData;
		
		#if debug
		for (i in first...first + k)
			assert(Std.is(d.get(i), Comparable), "element is not of type Comparable");
		#end
		
		var last = first + k - 1, lo = first, hi = last, d = mData;
		
		var i0, i1, i2, mid, t;
		var t0, t1, t2, pivot;
		
		if (k > 1)
		{
			i0 = first;
			i1 = i0 + (k >> 1);
			i2 = i0 + k - 1;
			
			t0 = cast(d.get(i0), Comparable<Dynamic>);
			t1 = cast(d.get(i1), Comparable<Dynamic>);
			t2 = cast(d.get(i2), Comparable<Dynamic>);
			
			t = t0.compare(t2);
			if (t < 0 && t0.compare(t1) < 0)
				mid = t1.compare(t2) < 0 ? i1 : i2;
			else
			{
				if (t1.compare(t0) < 0 && t1.compare(t2) < 0)
					mid = t < 0 ? i0 : i2;
				else
					mid = t2.compare(t0) < 0 ? i1 : i0;
			}
			
			pivot = cast(d.get(mid), Comparable<Dynamic>);
			d.set(mid, d.get(first));
			
			while (lo < hi)
			{
				while (pivot.compare(cast d.get(hi)) < 0 && lo < hi) hi--;
				if (hi != lo)
				{
					d.set(lo, d.get(hi));
					lo++;
				}
				while (pivot.compare(cast d.get(lo)) > 0 && lo < hi) lo++;
				if (hi != lo)
				{
					d.set(hi, d.get(lo));
					hi--;
				}
			}
			d.set(lo, cast pivot);
			quickSortComparable(first, lo - first);
			quickSortComparable(lo + 1, last - lo);
		}
	}
	
	function insertionSort(first:Int, k:Int, cmp:T->T->Int)
	{
		var j, a, b, d = mData;
		for (i in first + 1...first + k)
		{
			a = d.get(i);
			j = i;
			while (j > first)
			{
				b = d.get(j - 1);
				if (cmp(b, a) > 0)
				{
					d.set(j, b);
					j--;
				}
				else
					break;
			}
			d.set(j, a);
		}
	}
	
	function insertionSortComparable(first:Int, k:Int)
	{
		var d = mData;
		
		#if debug
		for (i in first...first + k)
			assert(Std.is(d.get(i), Comparable), "element is not of type Comparable");
		#end
		
		var j, a, b, u, v;
		for (i in first + 1...first + k)
		{
			a = d.get(i);
			u = cast(a, Comparable<Dynamic>);
			
			j = i;
			while (j > first)
			{
				b = d.get(j - 1);
				v = cast(b, Comparable<Dynamic>);
				
				if (u.compare(v) > 0)
				{
					d.set(j, b);
					j--;
				}
				else
					break;
			}
			d.set(j, a);
		}
	}
	
	/**
		Preallocates storage for `n` elements.
		
		May cause a reallocation, but has no effect on `this.size` and its elements.
		Useful before inserting a large number of elements as this reduces the amount of incremental reallocation.
	**/
	public function reserve(n:Int):ArrayList<T>
	{
		if (n > capacity)
		{
			capacity = n;
			resizeContainer(n);
		}
		return this;
	}
	
	/**
		Sets `n` elements to `val` (by reference).
		
		Automatically reserves storage for `n` elements so an additional call to `this.reserve()` is not required.
	**/
	public function init(n:Int, val:T):ArrayList<T>
	{
		reserve(n);
		mSize = n;
		var d = mData;
		for (i in 0...n) d.set(i, val);
		return this;
	}
	
	/**
		Reduces the capacity of the internal container to the initial capacity.
		
		May cause a reallocation, but has no effect on `this.size` and its elements.
		An application can use this operation to free up memory by unlocking resources for the garbage collector.
	**/
	public function pack():ArrayList<T>
	{
		if (capacity > mInitialCapacity)
		{
			capacity = M.max(mInitialCapacity, mSize);
			resizeContainer(capacity);
		}
		else
		{
			var d = mData;
			for (i in mSize...capacity) d.set(i, cast null);
		}
		return this;
	}
	
	/**
		Returns an `ArrayList` object storing elements in the range [`fromIndex`, `toIndex`).
		If `toIndex` is negative, the value represents the number of elements.
	**/
	public function getRange(fromIndex:Int, toIndex:Int):List<T>
	{
		assert(fromIndex >= 0 && fromIndex < size, "fromIndex out of range");
		#if debug
		if (toIndex >= 0)
		{
			assert(toIndex >= 0 && toIndex < size, "toIndex out of range");
			assert(fromIndex <= toIndex);
		}
		else
			assert(fromIndex - toIndex <= size, "toIndex out of range");
		#end
		
		var n = toIndex > 0 ? (toIndex - fromIndex) : ((fromIndex - toIndex) - fromIndex);
		var out = new ArrayList<T>(n);
		if (n == 0) return out;
		out.mSize = n;
		mData.blit(fromIndex, out.mData, 0, n);
		return out;
	}
	
	/**
		Make this an exact copy of `other`.
	**/
	public function of(other:ArrayList<T>):ArrayList<T>
	{
		clear();
		reserve(other.size);
		other.getData().blit(0, getData(), 0, other.size);
		mSize = other.size;
		return this;
	}
	
	/**
		Returns a reference to the internal container storing the elements of this collection.
		
		Useful for fast iteration or low-level operations.
	**/
	public inline function getData():NativeArray<T>
	{
		return mData;
	}
	
	function grow()
	{
		capacity = GrowthRate.compute(growthRate, capacity);
		resizeContainer(capacity);
	}
	
	function resizeContainer(newSize:Int)
	{
		var t = NativeArrayTools.alloc(newSize);
		mData.blit(0, t, 0, mSize);
		mData = t;
	}
	
	/* INTERFACE Collection */
	
	/**
		The total number of elements stored in this list.
	**/
	public var size(get, never):Int;
	inline function get_size():Int
	{
		return mSize;
	}
	
	/**
		Destroys this object by explicitly nullifying all elements for GC'ing used resources.
		
		Improves GC efficiency/performance (optional).
	**/
	public function free()
	{
		mData.nullify();
		mData = null;
		if (mIterator != null)
		{
			mIterator.free();
			mIterator = null;
		}
	}
	
	/**
		Returns true if this list contains `val`.
	**/
	public function contains(val:T):Bool
	{
		var d = mData;
		for (i in 0...size)
		{
			if (d.get(i) == val)
				return true;
		}
		return false;
	}
	
	/**
		Removes all occurrences of `val`.
		
		Shifts any subsequent elements to the left (indices - 1).
		@return true if at least one occurrence of `val` was removed.
	**/
	public function remove(val:T):Bool
	{
		if (isEmpty()) return false;
		
		var i = 0;
		var s = size;
		var d = mData;
		while (i < s)
		{
			if (d.get(i) == val)
			{
				//TODO optimize
				//#if (neko || java || cs || cpp)
				//d.blit(i + 1, d, i, s - i);
				//s--;
				//#else
				s--;
				var p = i;
				while (p < s)
				{
					d.set(p, d.get(p + 1));
					++p;
				}
				//#end
				continue;
			}
			i++;
		}
		var found = (size - s) != 0;
		mSize = s;
		return found;
	}
	
	/**
		Clears this list by nullifying all elements so the garbage collector can reclaim used memory.
	**/
	public function clear(gc:Bool = false)
	{
		if (gc) mData.nullify();
		mSize = 0;
	}
	
	/**
		Returns a new *ArrayListIterator* object to iterate over all elements contained in this list.
		
		Order: Row-major order (row-by-row).
		
		@see http://haxe.org/ref/iterators
	**/
	public function iterator():Itr<T>
	{
		if (reuseIterator)
		{
			if (mIterator == null)
				mIterator = new ArrayListIterator<T>(this);
			else
				mIterator.reset();
			return mIterator;
		}
		else
			return new ArrayListIterator<T>(this);
	}
	
	/**
		Returns true only if `this.size` is 0.
	**/
	public function isEmpty():Bool
	{
		return size == 0;
	}
	
	/**
		Returns an array containing all elements in this list.
		
		Preserves the natural order of this array.
	**/
	public function toArray():Array<T>
	{
		return mData.toArray(0, size, []);
	}
	
	/**
		Creates and returns a shallow copy (structure only - default) or deep copy (structure & elements) of this list.
		
		If `byRef` is true, primitive elements are copied by value whereas objects are copied by reference.
		
		If `byRef` is false, the `copier` function is used for copying elements. If omitted, `clone()` is called on each element assuming all elements implement `Cloneable`.
	**/
	public function clone(byRef:Bool = true, copier:T->T = null):Collection<T>
	{
		var out = new ArrayList<T>(capacity);
		out.mSize = size;
		var src = mData;
		var dst = out.mData;
		if (byRef)
			src.blit(0, dst, 0, size);
		else
		if (copier == null)
		{
			for (i in 0...size)
			{
				assert(Std.is(src.get(i), Cloneable), "element is not of type Cloneable");
				
				dst.set(i, cast(src.get(i), Cloneable<Dynamic>).clone());
			}
		}
		else
		{
			for (i in 0...size)
				dst.set(i, copier(src.get(i)));
		}
		return cast out;
	}
}

#if generic
@:generic
#end
@:access(de.polygonal.ds.ArrayList)
@:dox(hide)
class ArrayListIterator<T> implements de.polygonal.ds.Itr<T>
{
	var mObject:ArrayList<T>;
	var mData:NativeArray<T>;
	var mI:Int;
	var mS:Int;
	
	public function new(x:ArrayList<T>)
	{
		mObject = x;
		reset();
	}
	
	public function free()
	{
		mObject = null;
		mData = null;
	}
	
	public inline function reset():Itr<T>
	{
		mData = mObject.mData;
		mS = mObject.size;
		mI = 0;
		return this;
	}
	
	public inline function hasNext():Bool
	{
		return mI < mS;
	}
	
	public inline function next():T
	{
		return mData.get(mI++);
	}
	
	public function remove()
	{
		assert(mI > 0, "call next() before removing an element");
		
		mObject.removeAt(--mI);
		mS--;
	}
}