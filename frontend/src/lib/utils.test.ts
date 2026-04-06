import { describe, it, expect } from 'vitest';
import { cn } from './utils';

describe('utils', () => {
  describe('cn function', () => {
    it('should merge class names correctly', () => {
      const result = cn('class1', 'class2', 'class3');
      expect(result).toBe('class1 class2 class3');
    });

    it('should handle conditional class names', () => {
      const result = cn('class1', false && 'class2', 'class3');
      expect(result).toBe('class1 class3');
    });

    it('should handle undefined values', () => {
      const result = cn('class1', undefined, 'class2');
      expect(result).toBe('class1 class2');
    });

    it('should handle null values', () => {
      const result = cn('class1', null, 'class2');
      expect(result).toBe('class1 class2');
    });

    it('should handle empty strings', () => {
      const result = cn('class1', '', 'class2');
      expect(result).toBe('class1 class2');
    });

    it('should handle object notation', () => {
      const result = cn({
        class1: true,
        class2: false,
        class3: true,
      });
      expect(result).toBe('class1 class3');
    });

    it('should merge tailwind classes correctly', () => {
      const result = cn('px-4 py-2', 'px-6');
      // twMerge should override px-4 with px-6
      expect(result).toBe('py-2 px-6');
    });

    it('should handle conflicting tailwind classes', () => {
      const result = cn('text-red-500', 'text-blue-500');
      // twMerge should keep the last one
      expect(result).toBe('text-blue-500');
    });

    it('should handle arrays of classes', () => {
      const result = cn(['class1', 'class2'], 'class3');
      expect(result).toBe('class1 class2 class3');
    });

    it('should handle nested arrays', () => {
      const result = cn(['class1', ['class2', 'class3']], 'class4');
      expect(result).toBe('class1 class2 class3 class4');
    });

    it('should handle complex combinations', () => {
      const isActive = true;
      const isDisabled = false;
      
      const result = cn(
        'base-class',
        isActive && 'active',
        isDisabled && 'disabled',
        {
          'conditional-1': true,
          'conditional-2': false,
        },
        'final-class'
      );

      expect(result).toBe('base-class active conditional-1 final-class');
    });

    it('should handle responsive tailwind classes', () => {
      const result = cn('sm:text-sm', 'md:text-base', 'lg:text-lg');
      expect(result).toBe('sm:text-sm md:text-base lg:text-lg');
    });

    it('should handle state-based classes', () => {
      const result = cn('hover:bg-blue-100', 'focus:ring-2', 'active:bg-blue-200');
      expect(result).toBe('hover:bg-blue-100 focus:ring-2 active:bg-blue-200');
    });

    it('should override variants correctly', () => {
      const result = cn('bg-primary-500', 'bg-secondary-500');
      expect(result).toBe('bg-secondary-500');
    });

    it('should handle empty input', () => {
      const result = cn();
      expect(result).toBe('');
    });

    it('should handle all falsy values', () => {
      const result = cn(null, undefined, false, '', 0);
      expect(result).toBe('');
    });
  });
});