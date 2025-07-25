title: Stateful Streamplot Example
---

# Stateful Streamplot

This example shows time-evolving vector field animations using streamplots.

## Files

- `stateful_streamplot.f90` - Source code
- `stateful_streamplot.png/pdf/txt` - Static snapshot

## Running

```bash
make example ARGS="stateful_streamplot"
```

## Features Demonstrated

- **Time-dependent fields**: Vector fields that change over time
- **State preservation**: Maintain streamline continuity
- **Smooth transitions**: Interpolate between states
- **Physical simulations**: Fluid flow, electromagnetic fields

## Applications

- **Fluid dynamics**: Visualize flow evolution
- **Weather patterns**: Show wind field changes
- **Electromagnetic fields**: Time-varying E/B fields
- **Traffic flow**: Vehicle movement patterns

## Implementation Notes

- **Stateful integration**: Remember previous streamline positions
- **Adaptive refinement**: Add/remove streamlines as needed
- **Performance**: Optimized for real-time updates
- **Memory efficient**: Only store necessary state

## Output Example

![Stateful Streamplot](stateful_streamplot.png)