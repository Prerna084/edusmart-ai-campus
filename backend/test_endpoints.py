"""
Test script to validate all endpoints are properly registered
"""
from app import create_app
import sys

def main():
    try:
        app = create_app()
        
        # Collect all routes
        endpoints = {}
        for rule in app.url_map.iter_rules():
            if rule.endpoint != 'static':
                bp = rule.endpoint.split('.')[0] if '.' in rule.endpoint else 'root'
                if bp not in endpoints:
                    endpoints[bp] = []
                methods = ','.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))
                endpoints[bp].append((rule.rule, methods))
        
        # Print summary
        print("\n" + "="*70)
        print("✓ FLASK APP LOADED SUCCESSFULLY")
        print("="*70)
        print(f"\nTotal Blueprints: {len(endpoints)}")
        print(f"Total Endpoints: {sum(len(routes) for routes in endpoints.values())}\n")
        
        for bp_name in sorted(endpoints.keys()):
            print(f"\n{bp_name.upper()} Blueprint:")
            print("-" * 70)
            for route, methods in sorted(set(endpoints[bp_name])):
                print(f"  [{methods:15}] {route}")
        
        print("\n" + "="*70)
        return 0
        
    except Exception as e:
        print(f"\n✗ ERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
